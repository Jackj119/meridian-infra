variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name: dev, staging, or production. Used in resource names and tags."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be one of: dev, staging, production."
  }
}

variable "use_localstack" {
  description = "Send AWS calls to LocalStack instead of real AWS. Set to false in CI."
  type        = bool
  default     = true
}

variable "localstack_endpoint" {
  description = "LocalStack edge endpoint that all AWS service calls are sent to."
  type        = string
  default     = "http://localhost:4566"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type. t2.micro is Free Tier eligible in most regions."
  type        = string
  default     = "t2.micro"
}
