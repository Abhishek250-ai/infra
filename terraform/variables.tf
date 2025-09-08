variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets_cidrs" {
  type = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets_cidrs" {
  type = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "ecr_account_id" {
  type = string
  description = "ECR account id which hosts the images (548586340409)"
}

variable "patient_image" {
  type        = string
  description = "Full URI for patient image, e.g. 5485..../patient:latest"
}

variable "appointment_image" {
  type        = string
  description = "Full URI for appointment image, e.g. 5485..../appointment:latest"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "desired_count" {
  type    = number
  default = 2
}
