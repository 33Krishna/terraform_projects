# Primary VPC
resource "aws_vpc" "primary_vpc" {
  cidr_block           = var.primary_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "Primary-VPC-${var.primary_region}"
  })
}

# Secondary VPC in
resource "aws_vpc" "secondary_vpc" {
  provider             = aws.secondary
  cidr_block           = var.secondary_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "Secondary-VPC-${var.secondary_region}"
  })
}

# Subnet in Primary VPC
resource "aws_subnet" "primary_subnet" {
  vpc_id                  = aws_vpc.primary_vpc.id
  cidr_block              = var.primary_subnet_cidr
  availability_zone       = data.aws_availability_zones.primary.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "Primary-Subnet-${var.primary_region}"
  })
}

# Subnet in Secondary VPC
resource "aws_subnet" "secondary_subnet" {
  provider                = aws.secondary
  vpc_id                  = aws_vpc.secondary_vpc.id
  cidr_block              = var.secondary_subnet_cidr
  availability_zone       = data.aws_availability_zones.secondary.names[0]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "Secondary-Subnet-${var.secondary_region}"
  })
}

# Internet Gateway for Primary VPC
resource "aws_internet_gateway" "primary_igw" {
  vpc_id = aws_vpc.primary_vpc.id

  tags = merge(local.common_tags, {
    Name = "Primary-IGW"
  })
}

# Internet Gateway for Secondary VPC
resource "aws_internet_gateway" "secondary_igw" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary_vpc.id

  tags = merge(local.common_tags, {
    Name = "Secondary-IGW"
  })
}

# Route table for Primary VPC
resource "aws_route_table" "primary_rt" {
  vpc_id   = aws_vpc.primary_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary_igw.id
  }

  tags = merge(local.common_tags, {
    Name = "Primary-Route-Table"
  })
}

# Route table for Secondary VPC
resource "aws_route_table" "secondary_rt" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.secondary_igw.id
  }

  tags = merge(local.common_tags, {
    Name = "Secondary-Route-Table"
  })
}

# Associate route table with Primary subnet
resource "aws_route_table_association" "primary_rta" {
  subnet_id      = aws_subnet.primary_subnet.id
  route_table_id = aws_route_table.primary_rt.id
}

# Associate route table with Secondary subnet
resource "aws_route_table_association" "secondary_rta" {
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary_subnet.id
  route_table_id = aws_route_table.secondary_rt.id
}

# VPC Peering Connection (Requester side - Primary VPC)
resource "aws_vpc_peering_connection" "primary_to_secondary" {
  vpc_id      = aws_vpc.primary_vpc.id
  peer_vpc_id = aws_vpc.secondary_vpc.id
  peer_region = var.secondary_region
  auto_accept = false

  tags = merge(local.common_tags, {
    Name = "Primary-to-Secondary-Peering"
    Side = "Requester"
  })
}

# VPC Peering Connection Accepter (Accepter side - Secondary VPC)
resource "aws_vpc_peering_connection_accepter" "secondary_accepter" {
  provider                  = aws.secondary
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id
  auto_accept               = true

  tags = merge(local.common_tags, {
    Name = "Secondary-Peering-Accepter"
    Side = "Accepter"
  })
}

# Add route to Secondary VPC in Primary route table
resource "aws_route" "primary_to_secondary" {
  route_table_id            = aws_route_table.primary_rt.id
  destination_cidr_block    = var.secondary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id

  depends_on = [aws_vpc_peering_connection_accepter.secondary_accepter]
}

# Add route to Primary VPC in Secondary route table
resource "aws_route" "secondary_to_primary" {
  provider                  = aws.secondary
  route_table_id            = aws_route_table.secondary_rt.id
  destination_cidr_block    = var.primary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.primary_to_secondary.id

  depends_on = [aws_vpc_peering_connection_accepter.secondary_accepter]
}

# Security Group for Primary VPC EC2 instance
resource "aws_security_group" "primary_sg" {
  name        = "primary-vpc-sg"
  description = "Security group for Primary VPC instance"
  vpc_id      = aws_vpc.primary_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "ICMP from Secondary VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.secondary_vpc_cidr]
  }

  ingress {
    description = "All traffic from Secondary VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.secondary_vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "Primary-VPC-SG"
  })
}

# Security Group for Secondary VPC EC2 instance
resource "aws_security_group" "secondary_sg" {
  provider    = aws.secondary
  name        = "secondary-vpc-sg"
  description = "Security group for Secondary VPC instance"
  vpc_id      = aws_vpc.secondary_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "ICMP from Primary VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.primary_vpc_cidr]
  }

  ingress {
    description = "All traffic from Primary VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.primary_vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "Secondary-VPC-SG"
  })
}

# EC2 Instance in Primary VPC
resource "aws_instance" "primary_instance" {
  ami                    = data.aws_ami.primary_ami.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.primary_subnet.id
  vpc_security_group_ids = [aws_security_group.primary_sg.id]
  key_name               = var.primary_key_name

  user_data = local.primary_user_data

  depends_on = [aws_vpc_peering_connection_accepter.secondary_accepter] # this line is optional ( Overuse Line ) --> It can be removed cause this delaying the creation of EC2

  tags = merge(local.common_tags, {
    Name   = "Primary-VPC-Instance"
    Region = var.primary_region
  })
}

# EC2 Instance in Secondary VPC
resource "aws_instance" "secondary_instance" {
  provider               = aws.secondary
  ami                    = data.aws_ami.secondary_ami.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.secondary_subnet.id
  vpc_security_group_ids = [aws_security_group.secondary_sg.id]
  key_name               = var.secondary_key_name

  user_data = local.secondary_user_data

  depends_on = [aws_vpc_peering_connection_accepter.secondary_accepter] # this line is optional ( Overuse Line ) --> It can be removed cause this delaying the creation of EC2

  tags = merge(local.common_tags, {
    Name   = "Secondary-VPC-Instance"
    Region = var.secondary_region
  })
}

# NEXT STEPS
# 1. Add more subnets (private subnet)
# 2. Implement NAT gateway

# Primary Private Subnet
resource "aws_subnet" "primary_private_subnet" {
  vpc_id = aws_vpc.primary_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.primary.names[0]

  tags = merge(local.common_tags, {
    Name = "Primary-Private-Subnet"
  })
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "NAT-EIP"
  })
}

# NAT Gateway
resource "aws_nat_gateway" "primary_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.primary_subnet.id # Need to give public subnet

  depends_on = [aws_internet_gateway.primary_igw]

  tags = merge(local.common_tags, {
    Name = "Primary-NAT-Gateway"
  })
}

# Private Route Table
resource "aws_route_table" "primary_private_rt" {
  vpc_id = aws_vpc.primary_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.primary_nat.id
  }

  tags = merge(local.common_tags, {
    Name = "Primary-Private-RT"
  })
}

# Associate Private Route Table with Private Subnet
resource "aws_route_table_association" "primary_private_rta" {
  subnet_id      = aws_subnet.primary_private_subnet.id
  route_table_id = aws_route_table.primary_private_rt.id
}

# EC2 Instance in Private Subnet
resource "aws_instance" "primary_private_instance" {
  ami                    = data.aws_ami.primary_ami.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.primary_private_subnet.id
  vpc_security_group_ids = [aws_security_group.primary_sg.id]
  key_name               = var.primary_key_name

  user_data = local.primary_user_data

  tags = merge(local.common_tags, {
    Name   = "Primary-Private-Instance"
    Region = var.primary_region
  })
}


# NEXT STEP
# 3. Add VPC Flow Logs for traffic analysis

# IAM Role
resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

# Attach Policy to IAM Role
resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Resource = "*"
    }]
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name = "/aws/vpc/flow-logs"

  retention_in_days = 7
}

# Enable Primary VPC Flow Logs
resource "aws_flow_log" "primary_vpc_flow_logs" {
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"

  traffic_type = "ALL"
  vpc_id = aws_vpc.primary_vpc.id

  iam_role_arn = aws_iam_role.vpc_flow_logs_role.arn

  tags = merge(local.common_tags, {
    Name = "Primary-VPC-Flow-Logs"
  })
}

# Enable Secondary VPC Flow Logs (Optional)
resource "aws_flow_log" "secondary_vpc_flow_logs" {
  provider = aws.secondary

  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"

  traffic_type = "ALL"
  vpc_id = aws_vpc.secondary_vpc.id

  iam_role_arn = aws_iam_role.vpc_flow_logs_role.arn

  tags = merge(local.common_tags, {
    Name = "Secondary-VPC-Flow-Logs"
  })
}

# NEXT STEP
# 6. Implement Transit Gateway for complex topologies

# Creating Transit Gateway
resource "aws_ec2_transit_gateway" "tgw" {
  description = "Main Transit Gateway"

  tags = merge(local.common_tags, {
    Name = "Main-TGW"
  })
}

# Transit Gateway Attachment for Primary VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "primary_attachment" {
  subnet_ids = [aws_subnet.primary_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id = aws_vpc.primary_vpc.id

  tags = merge(local.common_tags, {
    Name = "Primary-TGW-Attachment"
  })
}

# Transit Gateway Attachment for Secondary VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "secondary_attachment" {
  provider = aws.secondary
  subnet_ids = [aws_subnet.secondary_subnet.id]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id = aws_vpc.secondary_vpc.id

  tags = merge(local.common_tags, {
    Name = "Secondary-TGW-Attachment"
  })
}

# Transit Gateway Routing for Primary VPC 
resource "aws_route" "primary_to_secondary_tgw" {
  route_table_id = aws_route_table.primary_rt.id
  destination_cidr_block = var.secondary_vpc_cidr
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
}

# Transit Gateway Routing for Secondary VPC 
resource "aws_route" "secondary_to_primary_tgw" {
  provider = aws.secondary
  route_table_id = aws_route_table.secondary_rt.id
  destination_cidr_block = var.primary_vpc_cidr
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
}

# NEXT STEP
# 5. Set up a VPN connection

# Create Customer Gateway (Your Side means Office Side router)
resource "aws_customer_gateway" "cg" {
  bgp_asn = 65000
  ip_address = var.my_ip # This should be On-premise router / firewall ka PUBLIC STATIC IP
  type = "ipsec.1"

  tags = merge(local.common_tags, {
    Name = "Customer-Gateway"
  })
}

# Create Virtual Private Gateway (AWS Side entry)
resource "aws_vpn_gateway" "vgw" {
  vpc_id = aws_vpc.primary_vpc.id

  tags = merge(local.common_tags, {
    Name = "Virtual-Private-Gateway"
  })
}

# Create VPN Connection
resource "aws_vpn_connection" "vpn" {
  vpn_gateway_id = aws_vpn_gateway.vgw.id
  customer_gateway_id = aws_customer_gateway.cg.id
  type = "ipsec.1"

  static_routes_only = true

  tags = merge(local.common_tags, {
    Name = "Site-to-Site-VPN-Connection"
  })
}

# Create VPN Connection Route
resource "aws_vpn_connection_route" "vpn_route" {
  vpn_connection_id = aws_vpn_connection.vpn.id
  destination_cidr_block = var.on_prem_cidr # Your local network ( On-premise/office network ka private IP range )
}

# Route Table Update for VPN
resource "aws_route" "primary_to_vpn" {
  route_table_id = aws_route_table.primary_rt.id
  destination_cidr_block = var.on_prem_cidr # Your local network ( On-premise/office network ka private IP range )
  gateway_id = aws_vpn_gateway.vgw.id
}

# If want to create VPN for secondary or other VPCs then don't use this basic messy method
# Use Transit Gateway instead (Office → VPN → TGW → All VPCs)
# VGW is per VPC, but TGW can connect VPN to multiple VPCs
# This VPN connection is not real connection but its a concept + infra setup
# For real connection you need to configure on-premise router / firewall
# In production, VPN is usually attached to a Transit Gateway, not directly to a single VPC