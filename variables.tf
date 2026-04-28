variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "admin_ip" {
  description = "Your public IPv4 in CIDR form for SSH to bastion (e.g., 203.0.113.25/32)"
  type        = string
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name to use for bastion SSH access"
  type        = string
}

variable "cloudtrail_bucket_name" {
  description = "CloudTrail logs S3 bucket name (must be globally unique — append your account ID or initials)"
  type        = string
}

variable "workflow_bucket_name" {
  description = "Workflow S3 bucket name for human and automation principals (must be globally unique)"
  type        = string
}

variable "ai_service_api_key" {
  description = "AI service API key stored in Secrets Manager — replaces plaintext EBS credential storage"
  type        = string
  sensitive   = true
}
