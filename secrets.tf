# secrets.tf
# AWS Secrets Manager - replaces plaintext EBS credential storage
# Encrypted, managed, auditable, and retrievable only by automation role
# Every retrieval logged in CloudTrail with principal identity and secret path
# Resolves information disclosure finding from dual identity threat model

resource "aws_secretsmanager_secret" "automation_credentials" {
  name        = "openclaw/automation/ai-service-api-key"
  description = "AI service API key for OpenClaw automation role - replaces plaintext EBS credential storage"

  # Secret rotation - deferred to part two (live agent demo)
  # rotation_lambda_arn = aws_lambda_function.rotation.arn

  tags = {
    Purpose = "Automation credential storage - encrypted managed auditable"
  }
}

resource "aws_secretsmanager_secret_version" "automation_credentials" {
  secret_id = aws_secretsmanager_secret.automation_credentials.id
  secret_string = jsonencode({
    api_key     = var.ai_service_api_key
    service     = "openclaw-ai-service"
    environment = "proof-of-concept"
  })
}
