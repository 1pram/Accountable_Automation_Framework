# network.tf
# VPC, subnets, routing, security groups, and VPC endpoints
# Private subnet has no internet route - AWS services accessed via VPC endpoints
# Bastion host is the single controlled entry point via SSH

# VPC
resource "aws_vpc" "tiered_identity_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "tiered-identity-vpc"
  }
}

# Public subnet - bastion host only
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.tiered_identity_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "tiered-identity-public"
  }
}

# Private subnet - Windows EC2 instance
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.tiered_identity_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "tiered-identity-private"
  }
}

# Internet gateway - bastion SSH access only
resource "aws_internet_gateway" "tiered_identity_igw" {
  vpc_id = aws_vpc.tiered_identity_vpc.id

  tags = {
    Name    = "tiered-identity-igw"
    Purpose = "Bastion SSH entry point only"
  }
}

# Public route table - internet gateway route for bastion
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.tiered_identity_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tiered_identity_igw.id
  }

  tags = {
    Name = "tiered-identity-public-rt"
  }
}

# Associate public route table with public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private route table - no internet route
# AWS services accessed exclusively via VPC endpoints
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.tiered_identity_vpc.id

  tags = {
    Name    = "tiered-identity-private-rt"
    Purpose = "No internet route - VPC endpoints only"
  }
}

# Associate private route table with private subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# -------------------
# Security Groups
# -------------------

# Bastion host security group - SSH your IP only
resource "aws_security_group" "bastion" {
  name        = "tiered-identity-bastion-sg"
  description = "Controls access to bastion host - SSH your IP only"
  vpc_id      = aws_vpc.tiered_identity_vpc.id

  ingress {
    description = "SSH from your IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tiered-identity-bastion-sg"
  }
}

# Windows instance security group - RDP from bastion only
resource "aws_security_group" "windows_instance" {
  name        = "tiered-identity-windows-sg"
  description = "Controls access to Windows EC2 instance - RDP from bastion only"
  vpc_id      = aws_vpc.tiered_identity_vpc.id

  ingress {
    description     = "RDP from bastion only"
    from_port       = 3389
    to_port         = 3389
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tiered-identity-windows-sg"
  }
}

# VPC endpoints security group - HTTPS from private subnet only
resource "aws_security_group" "vpc_endpoints" {
  name        = "tiered-identity-vpc-endpoints-sg"
  description = "Controls access to VPC interface endpoints"
  vpc_id      = aws_vpc.tiered_identity_vpc.id

  ingress {
    description = "HTTPS from private subnet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tiered-identity-vpc-endpoints-sg"
  }
}

# -------------------
# VPC Endpoints
# Eliminates NAT gateway requirement
# Private subnet never touches public internet
# -------------------

# S3 Gateway endpoint - free
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.tiered_identity_vpc.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name    = "tiered-identity-s3-endpoint"
    Purpose = "Private S3 access without internet route"
  }
}

# Secrets Manager Interface endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.tiered_identity_vpc.id
  service_name        = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name    = "tiered-identity-secretsmanager-endpoint"
    Purpose = "Private Secrets Manager access - replaces plaintext EBS credential storage"
  }
}

# CloudTrail Interface endpoint
resource "aws_vpc_endpoint" "cloudtrail" {
  vpc_id              = aws_vpc.tiered_identity_vpc.id
  service_name        = "com.amazonaws.us-east-1.cloudtrail"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name    = "tiered-identity-cloudtrail-endpoint"
    Purpose = "Private CloudTrail access for audit trail integrity"
  }
}
