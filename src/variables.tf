## names mostly self-explaatory, added
## descriptions only for those not immediately obvious

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

variable "public_eu_west_2a_cidr" {
  default = "10.0.0.0/24"
}

variable "public_eu_west_2b_cidr" {
  default = "10.0.1.0/24"
}

variable "private_eu_west_2a_cidr" {
  default = "10.0.8.0/24"
}

variable "private_eu_west_2b_cidr" {
  default = "10.0.16.0/24"
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
  default = "t2.micro"
}

variable "aws_amis" {
  default = {
    "eu-west-2" = "ami-06178cf087598769c"
  }
}

variable "alb_security_group_name" {
  default = "example_sg_from_outside"
}

variable "default_security_group_name" {
  default = "default_sg"
}

variable "instance_sg_ingress_cidr" {
  description = "What CIDR to allow http traffic from"   ## NOTE: I wasn't able to find an elegant way to do it but
                                                         ## we need to only limit this to the traffic coming from gateway +
                                                         ## internal corporate subet address for ssh access for instace
                                                         ## while on private subnet and not accessible from internet, this
                                                         ## would still make them accissble on the whole of the subnet
  default     = ["0.0.0.0/0"]
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

variable "asg_policy_name" {
  default     = "cpu-usage-trigger"
}

variable "scaling_policy_cpu_usage_target_value" {
  description = "target value for cpu usage before AWS scaling policies are alarmed and triggered"
  default     = 50.0
}
