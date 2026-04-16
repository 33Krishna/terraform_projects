aws_region = "us-east-1"

# Name of the Elastic Beanstalk application
# This will be used as a prefix for all resources
app_name = "my-app-bluegreen"

# Solution stack (platform) for Elastic Beanstalk
# To see available stacks, run:
# aws elasticbeanstalk list-available-solution-stacks --region us-east-1
solution_stack_name = "64bit Amazon Linux 2023 v6.2.0 running Node.js 20"
instance_type = "t3.micro"

tags = {
  Project     = "BlueGreenDeployment"
  Environment = "Production"
  ManagedBy   = "Terraform"
  Owner       = "Krishna"
}