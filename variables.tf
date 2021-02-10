variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "subnet_prefix" {
    description = "cidr block for the subnet"
}

variable "rds_instance_identifier" {}
variable "database_name" {}
variable "database_password" {}
variable "database_user" {}
variable "instance_class" {}
variable "ami_id" {}
variable "instance_type" {}
# variable "public_key_path" {}
variable "key_name" {}