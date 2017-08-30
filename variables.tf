variable "access_key" {}
variable "secret_key" {}
variable "aws_region" {}
variable "zones" {
  default = []
}
variable "private_subnets" {
  default = []
}
variable "public_subnets" {
  default = []
}
variable "ami" {}

variable "instance_type" {}
