# storage.tf
# Two S3 buckets with distinct purposes and access policies
# CloudTrail logs bucket - tamper proof, CloudTrail service access only
# Workflow bucket - human and automation principals, scoped by prefix

# -------------------
# CloudTrail Logs Bucket
# Written to exclusively by CloudTrail service
# Neither human user nor automation role can write or delete
# The camera that cannot be turned off
# -------------------

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "tiered-identity-cloudtrail-logs"
  force_destroy = true

  tags = {
    Purpose = "CloudTrail logs - tamper proof audit trail"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket                  = aws_s3_bucket.cloudtrail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket policy - CloudTrail service access only
# No principal can modify or delete logs
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# -------------------
# Workflow Bucket
# Shared by human user and automation role
# Access scoped by prefix - each principal has its own lane
# human/ prefix - human IAM user only
# automation/ prefix - automation role only
# -------------------

resource "aws_s3_bucket" "workflow" {
  bucket        = "tiered-identity-workflow"
  force_destroy = true

  tags = {
    Purpose = "Human and automation workflow storage - scoped by prefix"
  }
}

resource "aws_s3_bucket_public_access_block" "workflow" {
  bucket                  = aws_s3_bucket.workflow.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "workflow" {
  bucket = aws_s3_bucket.workflow.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "workflow" {
  bucket = aws_s3_bucket.workflow.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
