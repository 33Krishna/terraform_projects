terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket-krishna"
    key    = "terraform_projects/01_mini_project/terraform.tfstate"
    region = var.aws_region
  }
}