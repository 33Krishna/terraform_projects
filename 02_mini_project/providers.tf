terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 6.40.0"
    }
  }
}

provider "aws" {
  region = var.primary_region
  alias = "primary"
}

provider "aws" {
  region = var.secondary_region
  alias = "secondary"
}