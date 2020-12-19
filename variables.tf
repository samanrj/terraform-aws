variable "region" {
  default = "eu-west-2"
}

variable "aws_region" {
  default = "eu-west-2"
}

variable "availability_zones" {
  default = "eu-west-2a,eu-west-2b,eu-west-2c"
}

variable "instance_type" {
  default     = "t2.micro"
  description = "AWS instance type"
}

variable "aws_amis" {
  default = {
    "eu-west-2" = "ami-06178cf087598769c"
  }
}

variable "asg_min" {
  description = "Min numbers of servers in ASG"
  default     = "1"
}

variable "asg_max" {
  description = "Max numbers of servers in ASG"
  default     = "2"
}

variable "asg_desired" {
  description = "Desired numbers of servers in ASG"
  default     = "1"
}
