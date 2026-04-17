# AI service API key (stored encrypted in Secrets Manager)
# Replaces plaintext credential storage on unmanaged EBS volume
# Every retrieval logged in CloudTrail under automation role identity
# Secret rotation deferred to part two (live agent demo)
resource "aws_secretsmanager_secret" "automation_credentials" {
  name        = "openclaw/automation/ai-service-api-key"
  description = "AI service API key for OpenClaw automation role"
  tags        = { Purpose = "AutomationCredentials", Project = "AAF" }
}

resource "aws_secretsmanager_secret_version" "automation_credentials_value" {
  secret_id = aws_secretsmanager_secret.automation_credentials.id
  secret_string = jsonencode({
    api_key     = var.ai_service_api_key
    service     = "openclaw-ai-service"
    environment = "proof-of-concept"
  })
}
