variable "aws_region" {
  default = "eu-west-2"
}

variable "availability_zones" {
  default = "eu-west-2a,eu-west-2b,eu-west-2c"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "vpc_name" {
  default = "senseon_vpc"
}

variable "vpc_igw_name" {
  default = "VPC Internet Gateway"
}

variable "tls_private_key_algorithm" {
  default = "ECDSA"
}

variable "tls_cert_common_name" {
  default = "senseon.io"
}

variable "tls_cert_org" {
  default = "Senseon Tech Ltd."
}

variable "iam_cert_name" {
  default = "senseon_self_signed_cert"
}

variable "load_balancer_name" {
  default = "test-alb"
}

variable "target_group_name" {
  default = "test-target-group"
}

variable "launch_config_name" {
  default = "test-lc"
}

variable "instance_type" {
  default     = "t2.micro"
}

variable "aws_amis" {
  default = {
    "eu-west-2" = "ami-06178cf087598769c"
  }
}

variable "asg_name" {
  default     = "test_asg"
}

variable "asg_min" {
  description = "Min numbers of servers in ASG"
  default     = "2"
}

variable "asg_max" {
  description = "Max numbers of servers in ASG"
  default     = "4"
}

variable "asg_desired" {
  description = "Desired numbers of servers in ASG"
  default     = "2"
}
