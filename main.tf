terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region = var.aws_region
}

## find availability zones in the region using `aws ec2 describe-availability-zones`
## stick them in a variable and create a list here to be used within the file
locals {
  availability_zones = split(",", var.availability_zones)
}

## create a very generic VPC
resource "aws_vpc" "default" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

## create an internet gateway for the public subnets to enable
## communications to/from web
resource "aws_internet_gateway" "vpc_igw" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = var.vpc_igw_name
  }
}

## now let's create two Private and two Public subnets
## Public to bind the ALB to and Private for backend webservers (both for higher availability reasons)
resource "aws_subnet" "public_eu_west_2a" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-2a"

  tags = {
    Name = "Public Subnet eu-west-2a"
  }
}

resource "aws_subnet" "public_eu_west_2b" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-2b"

  tags = {
    Name = "Public Subnet eu-west-2b"
  }
}

resource "aws_subnet" "private_eu_west_2a" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.8.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-2a"

  tags = {
    Name = "Private Subnet eu-west-2a"
  }
}

resource "aws_subnet" "private_eu_west_2b" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.16.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-2b"

  tags = {
    Name = "Private Subnet eu-west-2b"
  }
}

## create a private key to be used in the disposable ssl cert we will
## be creating in the next step
resource "tls_private_key" "sample-private-key" {
  algorithm   = var.tls_private_key_algorithm
}

## now create the self-signed cert itself
## in reality and in prod, this won't be needed as most likely we have
## already uploaded our real existing domain certificates to IAM
resource "tls_self_signed_cert" "sample-tls-cert" {
  key_algorithm   = tls_private_key.sample-private-key.algorithm
  private_key_pem = tls_private_key.sample-private-key.private_key_pem

  subject {
    common_name  = var.tls_cert_common_name
    organization = var.tls_cert_org
  }

  validity_period_hours = 12

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

## add the certificate to IAM so we can refer to this
## in `certificate_arn` of the load balancer
resource "aws_iam_server_certificate" "sample-iam-cert" {
  name             = var.iam_cert_name
  certificate_body = tls_self_signed_cert.sample-tls-cert.cert_pem
  private_key      = tls_private_key.sample-private-key.private_key_pem
}

## now let's create an Application Load Balancer (ALB) as it's most
## suitable for use case of https->http application-level forwarding
resource "aws_lb" "web-proxy" {
  name               = var.load_balancer_name
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_eu_west_2a.id,aws_subnet.public_eu_west_2b.id]
}

## let's create a target backend group for the ALB so
## we can later attach this to an autoscaling group
## they will be listening on 80/http
resource "aws_lb_target_group" "web-proxy" {
  name     = var.target_group_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.default.id

  ## the health check here is redundant IMO, ASG will be carrying that out anyway
  # health_check {
  #   healthy_threshold   = 2
  #   unhealthy_threshold = 2
  #   timeout             = 3
  #   interval            = 30
  # }
}

## now let's create the listener and forwarding rules for the lb
## listening on 443/https and forwarding to the backend TG
resource "aws_lb_listener" "web-proxy" {
  load_balancer_arn = aws_lb.web-proxy.arn
  port              = "443"
  protocol          = "HTTPS"
  # ssl_policy        = "ELBSecurityPolicy-2016-08"  ?
  certificate_arn   = "arn:aws:iam::151204058273:server-certificate/senseon_self_signed_cert"  ## this needs to be done better

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web-proxy.arn
  }
}

## now let's create an ASG and
## pass the target group created above to it
resource "aws_autoscaling_group" "web-asg" {
  max_size                  = var.asg_max
  min_size                  = var.asg_min
  desired_capacity          = var.asg_desired
  force_delete              = true
  name                      = var.asg_name ## needed a way to reference this in the last block
  health_check_grace_period = 300
  launch_configuration      = aws_launch_configuration.web-lc.name

  vpc_zone_identifier  = [
    aws_subnet.private_eu_west_2a.id,
    aws_subnet.private_eu_west_2b.id
  ]

  # load_balancers       = [aws_lb.web-proxy.name]
  target_group_arns         = [aws_lb_target_group.web-proxy.arn]   # ===> https://github.com/terraform-aws-modules/terraform-aws-autoscaling/issues/16#issuecomment-365388692
                                                                    # `load_balancers` only seem to work with ELB
                                                                    # the other alternative I found was using `aws_autoscaling_attachment` defined here:
                                                                    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment
  tag {
    key                 = "Name"
    value               = var.asg_name
    propagate_at_launch = "true"
  }
}

## and a launch configuration template for EC2 instances
## the asg will attempt to bring up / maintain
resource "aws_launch_configuration" "web-lc" {
  name          = var.launch_config_name
  image_id      = var.aws_amis[var.aws_region]
  instance_type = var.instance_type

  # Security group
  security_groups = [aws_security_group.default.id]
  user_data       = file("install_apache.sh")   ## to display some welcome message when we hit
                                                ## the final test dns given to us by the ALB
  lifecycle {
    create_before_destroy = true
  }
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "from_web" {
  name        = var.alb_security_group_name
  description = "Used for allowing https access to the ALB"

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = var.default_security_group_name
  description = "only from Load Balancer"

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.instance_sg_ingress_cidr
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.instance_sg_ingress_cidr
  }
}

## more advanced usage, let's create a scaling policy
## based on CPU usage for AWS to dynamically scale the ASG
## once it detects higher levels of traffic and hence CPU usage higher than 50%
## picked that value based on some best practices, but made configurable
resource "aws_autoscaling_policy" "dynamic_scaling" {

  name                   = var.asg_policy_name
  autoscaling_group_name = aws_autoscaling_group.web-asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.scaling_policy_cpu_usage_target_value
  }
}
