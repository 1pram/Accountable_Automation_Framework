# iam.tf
# All IAM resources for tiered identity proof of concept
# Three principals: human user, automation role, CloudTrail reader
# Each scoped to exactly what it needs - no broader than necessary

# -------------------
# Human IAM User
# Permanent identity with long-term credentials
# Configured as named CLI profile on Windows instance
# -------------------

resource "aws_iam_user" "human_user" {
  name = "tiered-identity-human-user"

  tags = {
    Purpose = "Human principal for tiered identity proof of concept"
  }
}

resource "aws_iam_access_key" "human_user" {
  user = aws_iam_user.human_user.name
}

resource "aws_iam_policy" "human_user_policy" {
  name        = "tiered-identity-human-user-policy"
  description = "Scoped permissions for human principal"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListUsers"
        Effect = "Allow"
        Action = [
          "iam:ListUsers",
          "iam:GetUser",
          "iam:ListUserPolicies",
          "iam:ListAttachedUserPolicies",
          "iam:ListGroupsForUser"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowWorkflowBucketHumanPrefix"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.workflow.arn}/human/*"
      },
      {
        Sid    = "AllowListWorkflowBucket"
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = aws_s3_bucket.workflow.arn
        Condition = {
          StringLike = {
            "s3:prefix" = ["human/*"]
          }
        }
      },
      {
        Sid    = "AllowRebootInstance"
        Effect = "Allow"
        Action = "ec2:RebootInstances"
        Resource = "*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Project" = "Dual identity problem"
          }
        }
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "human_user" {
  user       = aws_iam_user.human_user.name
  policy_arn = aws_iam_policy.human_user_policy.arn
}

# -------------------
# Automation IAM Role
# Assumable identity with temporary credentials
# Assumed automatically via EC2 instance profile
# Outside human user's direct control - governed by security/IT
# -------------------

# Permissions boundary - maximum permission ceiling
# Enforced regardless of attached policies
# Explicitly denies CloudTrail modification and EBS snapshots
resource "aws_iam_policy" "automation_role_boundary" {
  name        = "tiered-identity-automation-boundary"
  description = "Maximum permission ceiling for automation role - cannot be exceeded by attached policies"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedActions"
        Effect = "Allow"
        Action = [
          "iam:ListUsers",
          "iam:GetUser",
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Sid    = "ExplicitDenyCloudTrail"
        Effect = "Deny"
        Action = [
          "cloudtrail:StartLogging",
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "cloudtrail:UpdateTrail"
        ]
        Resource = "*"
      },
      {
        Sid    = "ExplicitDenySnapshots"
        Effect = "Deny"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CopySnapshot",
          "ec2:ModifySnapshotAttribute"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "automation_role" {
  name                 = "tiered-identity-automation-role"
  description          = "Automation principal for OpenClaw agent simulation"
  permissions_boundary = aws_iam_policy.automation_role_boundary.arn

  # Trust policy - only EC2 instances can assume this role
  # Human user cannot assume directly - architectural separation enforced
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Assumption"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Purpose = "Automation principal - scoped to ListUsers and workflow bucket automation prefix"
  }
}

resource "aws_iam_policy" "automation_role_policy" {
  name        = "tiered-identity-automation-role-policy"
  description = "Scoped permissions for automation principal - within permissions boundary ceiling"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowListUsers"
        Effect = "Allow"
        Action = [
          "iam:ListUsers",
          "iam:GetUser"
        ]
        Resource = "*"
      },
      {
        Sid      = "AllowWorkflowBucketAutomationPrefix"
        Effect   = "Allow"
        Action   = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.workflow.arn}/automation/*"
      },
      {
        Sid    = "AllowListWorkflowBucket"
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = aws_s3_bucket.workflow.arn
        Condition = {
          StringLike = {
            "s3:prefix" = ["automation/*"]
          }
        }
      },
      {
        Sid    = "AllowSecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.automation_credentials.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "automation_role" {
  role       = aws_iam_role.automation_role.name
  policy_arn = aws_iam_policy.automation_role_policy.arn
}

# Instance profile - attaches automation role to EC2 instance
resource "aws_iam_instance_profile" "automation" {
  name = "tiered-identity-automation-profile"
  role = aws_iam_role.automation_role.name
}

# -------------------
# CloudTrail Reader Role
# Attached to bastion host via instance profile
# Read-only access to CloudTrail logs and S3 bucket
# Cannot modify trail or write to logs bucket
# -------------------

resource "aws_iam_policy" "cloudtrail_reader_policy" {
  name        = "tiered-identity-cloudtrail-reader-policy"
  description = "Read-only access to CloudTrail logs - cannot modify trail or logs bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudTrailLookup"
        Effect = "Allow"
        Action = [
          "cloudtrail:LookupEvents",
          "cloudtrail:GetTrail",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:DescribeTrails"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowCloudTrailS3Read"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.cloudtrail_logs.arn,
          "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "cloudtrail_reader_role" {
  name        = "tiered-identity-cloudtrail-reader-role"
  description = "CloudTrail read access for bastion host observation point"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Purpose = "CloudTrail observation - read only"
  }
}

resource "aws_iam_role_policy_attachment" "cloudtrail_reader" {
  role       = aws_iam_role.cloudtrail_reader_role.name
  policy_arn = aws_iam_policy.cloudtrail_reader_policy.arn
}

resource "aws_iam_instance_profile" "cloudtrail_reader" {
  name = "tiered-identity-cloudtrail-reader-profile"
  role = aws_iam_role.cloudtrail_reader_role.name
}
