variable "name" {
  default = "consul"
}

variable "environment" {}

variable "user" {
  default = "ubuntu"
}

variable "region" {
  description = "AWS Region for Consul"
}

variable "instance_type" {
  default = "t2.small"
}

variable "nodes" {
  default = "1"
}

variable "vpc_id" {}
variable "subnet_ids" {}
variable "private_ips" {}

variable "encryption" {}
variable "ca" {}
variable "tls_cert" {}
variable "tls_key" {}

variable "ec2_key_name" {}
variable "private_key" {}

variable "server_security_group_id" {}
variable "agent_security_group_id" {}

# Bastion configuration
variable "bastion_host" {}
variable "bastion_user" {}
variable "bastion_private_key" {}
variable "bastion_security_group_id" {}

variable "acl_datacenter" {
  default = ""
}
variable "acl_master_token" {
  default = ""
}
variable "atlas_username" {}
variable "atlas_token" {}
variable "atlas_environment" {}
variable "ami_artifact_version" {
  default = "latest"
}
