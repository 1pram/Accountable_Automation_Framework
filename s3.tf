# CloudTrail logs bucket
# Written to exclusively by CloudTrail service
# Neither human user nor automation role can write or delete
# The camera that cannot be turned off
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = var.cloudtrail_bucket_name
  tags = {
    Purpose = "CloudTrailLogs"
    Project = "AAF"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs_block" {
  bucket                  = aws_s3_bucket.cloudtrail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs_versioning" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs_sse" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket policy (CloudTrail service access only)
resource "aws_s3_bucket_policy" "cloudtrail_logs_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    : "AWSCloudTrailAclCheck",
        Effect : "Allow",
        Principal : { Service : "cloudtrail.amazonaws.com" },
        Action   : "s3:GetBucketAcl",
        Resource : aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    : "AWSCloudTrailWrite",
        Effect : "Allow",
        Principal : { Service : "cloudtrail.amazonaws.com" },
        Action   : "s3:PutObject",
        Resource : "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/*",
        Condition : { StringEquals : { "s3:x-amz-acl" : "bucket-owner-full-control" } }
      }
    ]
  })
}

# Workflow bucket, shared by human and automation principals
# Access scoped by prefix. Each principal operates in its own lane
# human/ prefix: human IAM user only
# automation/ prefix: automation role only
resource "aws_s3_bucket" "workflow" {
  bucket = var.workflow_bucket_name
  tags = {
    Purpose = "WorkflowStorage"
    Project = "AAF"
  }
}

resource "aws_s3_bucket_public_access_block" "workflow_block" {
  bucket                  = aws_s3_bucket.workflow.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "workflow_versioning" {
  bucket = aws_s3_bucket.workflow.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "workflow_sse" {
  bucket = aws_s3_bucket.workflow.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
