########################################
# AWS + VPC
########################################
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

########################################
# ECS + Containers
########################################
variable "container_port" {
  description = "Port for ECS containers"
  type        = number
  default     = 3000
}

variable "appointment_container_port" {
  description = "Port for appointment ECS container"
  type        = number
  default     = 3001
}


variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "patient_image" {
  description = "ECR image URI for patient service"
  type        = string
}

variable "appointment_image" {
  description = "ECR image URI for appointment service"
  type        = string
}


