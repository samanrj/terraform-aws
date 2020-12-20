terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  region = var.aws_region
}

locals {
  availability_zones = split(",", var.availability_zones)
}

resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "tf_test"
  }
}

resource "aws_internet_gateway" "vpc_igw" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "VPC Internet Gateway"
  }
}

resource "aws_subnet" "tf_test_subnet1" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-2a"

  tags = {
    Name = "tf_test_subnet1"
  }
}

resource "aws_subnet" "tf_test_subnet2" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.8.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-2b"

  tags = {
    Name = "tf_test_subnet2"
  }
}

resource "tls_private_key" "example" {
  algorithm   = "ECDSA"
}

resource "tls_self_signed_cert" "example" {
  key_algorithm   = tls_private_key.example.algorithm
  private_key_pem = tls_private_key.example.private_key_pem

  subject {
    common_name  = "example.com"
    organization = "ACME Examples, Inc"
  }

  validity_period_hours = 12

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_iam_server_certificate" "example" {
  name             = "example_self_signed_cert"
  certificate_body = tls_self_signed_cert.example.cert_pem
  private_key      = tls_private_key.example.private_key_pem
}

resource "aws_lb" "front_end" {
  name               = "test-lb-tf"   #var.alb_name
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.tf_test_subnet1.id,aws_subnet.tf_test_subnet2.id]
}

# ## Security Group for ELB
# resource "aws_security_group" "elb" {
#   name = "terraform-example-elb"
#   egress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   ingress {
#     from_port = 80
#     to_port = 80
#     protocol = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

resource "aws_lb_target_group" "front_end" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.default.id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.front_end.arn
  port              = "443"
  protocol          = "HTTPS"
  # ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:iam::151204058273:server-certificate/example_self_signed_cert"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.arn
  }
}





resource "aws_autoscaling_group" "web-asg" {
  availability_zones        = local.availability_zones
  name                      = "terraform-example-asg"
  max_size                  = var.asg_max
  min_size                  = var.asg_min
  desired_capacity          = var.asg_desired
  force_delete              = true
  health_check_grace_period = 300
  launch_configuration      = aws_launch_configuration.web-lc.name

  # load_balancers       = [aws_lb.front_end.name]
  target_group_arns         = [aws_lb_target_group.front_end.arn]   # ===> https://github.com/terraform-aws-modules/terraform-aws-autoscaling/issues/16

  tag {
    key                 = "Name"
    value               = "web-asg"
    propagate_at_launch = "true"
  }
}

resource "aws_launch_configuration" "web-lc" {
  name          = "terraform-example-lc"
  image_id      = var.aws_amis[var.aws_region]
  instance_type = var.instance_type

  # Security group
  security_groups = [aws_security_group.default.id]
  user_data       = file("install_apache.sh")

  lifecycle {
    create_before_destroy = true
  }
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "terraform_example_sg"
  description = "Used in the terraform"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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


# # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment
# # Create a new ALB Target Group attachment
# resource "aws_autoscaling_attachment" "asg_attachment_bar" {
#   autoscaling_group_name = aws_autoscaling_group.asg.id
#   alb_target_group_arn   = aws_alb_target_group.test.arn
# }




# # target_tracking_configuration - (Optional) A target tracking policy. These have the following structure:
# resource "aws_autoscaling_policy" "example" {
#   # ... other configuration ...
#
#   target_tracking_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ASGAverageCPUUtilization"
#     }
#
#     target_value = 40.0
#   }
#
#   target_tracking_configuration {
#     customized_metric_specification {
#       metric_dimension {
#         name  = "fuga"
#         value = "fuga"
#       }
#
#       metric_name = "hoge"
#       namespace   = "hoge"
#       statistic   = "Average"
#     }
#
#     target_value = 40.0
#   }
# }




# module "alb" {
#   source  = "terraform-aws-modules/alb/aws"
#   version = "~> 5.0"
#
#   name = "my-alb"
#
#   load_balancer_type = "application"
#
#   vpc_id             = "vpc-abcde012"
#   subnets            = ["subnet-abcde012", "subnet-bcde012a"]
#   security_groups    = ["sg-edcd9784", "sg-edcd9785"]
#
#   access_logs = {
#     bucket = "my-alb-logs"
#   }
#
#   target_groups = [
#     {
#       name_prefix      = "pref-"
#       backend_protocol = "HTTPS"
#       backend_port     = 443
#       target_type      = "instance"
#     }
#   ]
#
#   https_listeners = [
#     {
#       port                 = 443
#       protocol             = "HTTPS"
#       certificate_arn      = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"
#       action_type          = "authenticate-cognito"
#       target_group_index   = 0
#       authenticate_cognito = {
#         user_pool_arn       = "arn:aws:cognito-idp::123456789012:userpool/test-pool"
#         user_pool_client_id = "6oRmFiS0JHk="
#         user_pool_domain    = "test-domain-com"
#       }
#     }
#   ]
#
#   http_tcp_listeners = [
#     {
#       port        = 80
#       protocol    = "HTTP"
#       action_type = "redirect"
#       redirect = {
#         port        = "443"
#         protocol    = "HTTPS"
#         status_code = "HTTP_301"
#       }
#     }
#   ]
#
#   tags = {
#     Environment = "Test"
#   }
# }
