variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "prueba-simetrik"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_version" {
  description = "EKS cluster version."
  type        = string
  default     = "1.30"
}

variable "ami_release_version" {
  description = "Default EKS AMI release version for node groups"
  type        = string
  default     = "1.30.0-20240625"
}

variable "connection_arn" {
  description = "connection arn to my personal repository"
  type        = string
  default     = "arn:aws:codeconnections:us-east-1:014498650162:connection/533ea77d-898b-433a-b955-eef35617bf2a"
}

variable "vpc_cidr" {
  description = "Defines the CIDR block used on Amazon VPC created for Amazon EKS."
  type        = string
  default     = "10.42.0.0/16"
}