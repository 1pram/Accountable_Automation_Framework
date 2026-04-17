locals {
  az = "${var.aws_region}a"
}

# Public subnet — bastion host only
resource "aws_subnet" "public_bastion" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = true
  tags                    = { Name = "public-bastion" }
}

# Private subnet — Windows EC2 instance (OpenClaw execution environment)
resource "aws_subnet" "private_windows" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags                    = { Name = "private-windows" }
}

# Public route table — Internet gateway route for bastion SSH access only
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_bastion.id
  route_table_id = aws_route_table.public_rt.id
}

# Private route table (No internet route)
# AWS services reached exclusively via VPC endpoints
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "private-rt" }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_windows.id
  route_table_id = aws_route_table.private_rt.id
}
