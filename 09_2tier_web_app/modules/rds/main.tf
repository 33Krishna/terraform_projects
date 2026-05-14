# RDS Module - Main Configuration

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db"
  db_name = var.db_name

  # Storage
  allocated_storage = var.allocated_storage
  storage_type = "gp2"
  storage_encrypted = true

  # Engine
  engine       = var.engine
  engine_version = var.engine_version
  parameter_group_name = "default.${var.engine}${var.engine_version}"

  # Compute
  instance_class = var.instance_class

  # Credentials - secrets module se aate hain
  username = var.db_username
  password = var.db_password

  # Lifecycle
  skip_final_snapshot = true
  
  # Networking
  vpc_security_group_ids = [var.db_security_group_id]
  db_subnet_group_name = aws_db_subnet_group.main.name
  publicly_accessible = false

  tags = {
    Name = "${var.project_name}-rds"
    Environment = var.environment
  }
}