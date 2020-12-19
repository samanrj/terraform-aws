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
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.tf_test_subnet1.id,aws_subnet.tf_test_subnet2.id]
}

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
