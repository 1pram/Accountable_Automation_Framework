output "bastion_public_ip" {
  description = "Public IP of bastion host — SSH entry point"
  value       = aws_instance.bastion.public_ip
}

output "windows_private_ip" {
  description = "Private IP of Windows instance — RDP via bastion"
  value       = aws_instance.windows.private_ip
}

output "human_user_access_key" {
  description = "Human IAM user access key ID — configure as named profile on Windows instance"
  value       = aws_iam_access_key.human_user.id
}

output "human_user_secret_key" {
  description = "Human IAM user secret key — configure as named profile on Windows instance"
  value       = aws_iam_access_key.human_user.secret
  sensitive   = true
}

output "cloudtrail_bucket" {
  description = "CloudTrail logs S3 bucket name"
  value       = aws_s3_bucket.cloudtrail_logs.id
}

output "workflow_bucket" {
  description = "Workflow S3 bucket name"
  value       = aws_s3_bucket.workflow.id
}

output "secrets_manager_arn" {
  description = "Automation credentials secret ARN"
  value       = aws_secretsmanager_secret.automation_credentials.arn
}

output "automation_role_arn" {
  description = "Automation IAM role ARN"
  value       = aws_iam_role.automation_role.arn
}
