# S3 Gateway endpoint 
# Allows private subnet to reach S3 without NAT or public internet
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_rt.id]
  tags              = { Name = "s3-endpoint" }
}

# Secrets Manager interface endpoint
# Enables encrypted credential retrieval from private subnet
# Replaces plaintext credential storage on unmanaged EBS volume
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_windows.id]
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true
  tags                = { Name = "secretsmanager-endpoint" }
}

# CloudTrail interface endpoint
# Ensures audit trail delivery stays within the private network
resource "aws_vpc_endpoint" "cloudtrail" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.cloudtrail"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_windows.id]
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = true
  tags                = { Name = "cloudtrail-endpoint" }
}
