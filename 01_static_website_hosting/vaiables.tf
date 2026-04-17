variable "aws_region" {
    description = "AWS Region"
    type = string
    default = "us-east-1"
}

variable "bucket_prefix" {
  description = "Prefix for the S3 bucket name."
  type        = string
  default     = "my-static-website-"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "domain_name" {
  description = "Custom Domain Name"
  type        = string
  default     = "example.com"
}