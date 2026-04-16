terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket-krishna"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}