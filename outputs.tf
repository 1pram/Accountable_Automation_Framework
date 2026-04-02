# outputs.tf
# Values needed after terraform apply to configure proof of concept

output "bastion_public_ip" {
  description = "Bastion host public IP - SSH entry point"
  value       = aws_instance.bastion.public_ip
}

output "windows_private_ip" {
  description = "Windows instance private IP - RDP via bastion"
  value       = aws_instance.windows.private_ip
}

output "human_user_access_key" {
  description = "Human IAM user access key ID - configure as named profile on Windows instance"
  value       = aws_iam_access_key.human_user.id
}

output "human_user_secret_key" {
  description = "Human IAM user secret key - configure as named profile on Windows instance"
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

output "next_steps" {
  description = "Post-apply configuration steps"
  value       = <<-EOT

    NEXT STEPS AFTER TERRAFORM APPLY
    ==================================

    1. SSH into bastion:
       ssh -i ~/.ssh/your-key.pem ec2-user@${aws_instance.bastion.public_ip}

    2. From bastion, RDP into Windows instance:
       xfreerdp /u:Administrator /v:${aws_instance.windows.private_ip} /port:3389

    3. On Windows instance, configure human user profile:
       aws configure --profile human-user
       Access Key: ${aws_iam_access_key.human_user.id}
       Secret Key: (run: terraform output human_user_secret_key)
       Region: us-east-1

    4. Run automation role script:
       C:\workflow\automation\run-automation.ps1

    5. Run human user script:
       C:\workflow\human\run-human.ps1

    6. From bastion, query CloudTrail:
       ./query-cloudtrail.sh

  EOT
}
