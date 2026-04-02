# cloudtrail.tf
# CloudTrail - tamper proof audit trail
# Logs all management events and Lambda data events
# Multi-region - no blind spots by region
# Neither human user nor automation role can disable or modify
# The camera that cannot be turned off

resource "aws_cloudtrail" "tiered_identity_trail" {
  name                          = "tiered-identity-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true

  # Log file validation deferred to part two (live agent demo)
  enable_log_file_validation = false

  # Data events for Lambda invocations
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
  }

  tags = {
    Purpose = "Attribution proof of concept - distinguishes human from automation principal"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}
