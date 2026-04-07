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