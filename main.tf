# Bastion: SSH only from your admin IP
resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "Allow SSH from admin IP only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bastion-sg" }
}

# Windows instance: RDP allowed only from bastion SG
resource "aws_security_group" "windows_instance" {
  name        = "windows-instance-sg"
  description = "Allow RDP from bastion only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "RDP from bastion SG"
    from_port       = 3389
    to_port         = 3389
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "windows-sg" }
}

# VPC endpoints: HTTPS from private subnet only
resource "aws_security_group" "endpoints_sg" {
  name        = "vpc-endpoints-sg"
  description = "Allow HTTPS from private subnet to interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from private subnet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.private_windows.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "endpoints-sg" }
}
