# Multi-region trail (no blind spots by region)
# include_global_service_events captures IAM AssumeRole calls
# Log file validation deferred to part two (live agent demo)
resource "aws_cloudtrail" "aaf_trail" {
  name                          = "aaf-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = false

    tags = { Purpose = "AttributionTrail", Project = "AAF" }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs_policy]
}
