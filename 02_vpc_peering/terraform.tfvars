
primary_region   = "us-east-1"
secondary_region = "us-west-2"

primary_vpc_cidr   = "10.0.0.0/16"
secondary_vpc_cidr = "10.1.0.0/16"

primary_subnet_cidr   = "10.0.1.0/24"
secondary_subnet_cidr = "10.1.1.0/24"

instance_type = "t3.micro"

primary_key_name   = "primary-vpc-peering"
secondary_key_name = "secondary-vpc-peering"

my_ip = "49.42.179.76/32" # Change this to your own IP address