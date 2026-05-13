# General Settings
project_name = "2tier-web-app"
environment  = "dev"
aws_region   = "ap-south-1"

# VPC Settings
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidr   = "10.0.1.0/24"
private_subnet_cidrs = ["10.0.2.0/24", "10.0.3.0/24"]

# EC2 Settings
ec2_instance_type = "t3.micro"

# RDS Settings
db_name              = "webappdb"
db_username          = "admin"
# db_password is now automatically generated and stored in Secrets Manager
db_instance_class    = "db.t3.micro"
db_allocated_storage = 10
db_engine_version    = "8.0"