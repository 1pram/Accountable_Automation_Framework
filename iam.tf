data "aws_caller_identity" "current" {}

# Bastion (Jump host). It hosts the CloudTrail reader role
# Has Read-only access to trail and logs bucket
# Cannot modify or disable the audit trail

resource "aws_iam_role" "bastion_role" {
  name = "BastionCloudTrailReaderRole"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [{
      Effect : "Allow",
      Principal : { Service : "ec2.amazonaws.com" },
      Action : "sts:AssumeRole"
    }]
  })
  tags = { Purpose = "Bastion-CloudTrailReader" }
}

resource "aws_iam_policy" "cloudtrail_reader" {
  name        = "CloudTrailReaderPolicy"
  description = "Read-only access to CloudTrail events and logs bucket — observation only"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    : "AllowTrailLookup",
        Effect : "Allow",
        Action : [
          "cloudtrail:LookupEvents",
          "cloudtrail:GetTrail",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:DescribeTrails"
        ],
        Resource : "*"
      },
      {
        Sid    : "AllowLogsRead",
        Effect : "Allow",
        Action : ["s3:GetObject", "s3:ListBucket"],
        Resource : [
          aws_s3_bucket.cloudtrail_logs.arn,
          "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_reader_attach" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.cloudtrail_reader.arn
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = "BastionInstanceProfile"
  role = aws_iam_role.bastion_role.name
}

# Human IAM user
# Permanent identity with long-term credentials
# Configured as named CLI profile on Windows instance
# Actions are logged under the human user identity in CloudTrail

resource "aws_iam_user" "human_user" {
  name = "aaf-human-user"
  tags = { Purpose = "HumanPrincipal" }
}

resource "aws_iam_access_key" "human_user" {
  user = aws_iam_user.human_user.name
}

resource "aws_iam_policy" "human_user_policy" {
  name        = "HumanUserPolicy"
  description = "Scoped permissions for human principal — ListUsers, human S3 prefix, instance reboot"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    : "AllowListUsers",
        Effect : "Allow",
        Action : [
          "iam:ListUsers",
          "iam:GetUser",
          "iam:ListUserPolicies",
          "iam:ListAttachedUserPolicies",
          "iam:ListGroupsForUser"
        ],
        Resource : "*"
      },
      {
        Sid    : "AllowHumanPrefix",
        Effect : "Allow",
        Action : ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
        Resource : "${aws_s3_bucket.workflow.arn}/human/*"
      },
      {
        Sid      : "AllowListHumanPrefix",
        Effect   : "Allow",
        Action   : ["s3:ListBucket"],
        Resource : aws_s3_bucket.workflow.arn,
        Condition : { StringLike : { "s3:prefix" : ["human/*"] } }
      },
      {
        Sid    : "AllowReboot",
        Effect : "Allow",
        Action : ["ec2:RebootInstances"],
        Resource : "*",
        Condition : { StringEquals : { "ec2:ResourceTag/Project" : "AAF" } }
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "human_user_attach" {
  user       = aws_iam_user.human_user.name
  policy_arn = aws_iam_policy.human_user_policy.arn
}

# Automation role. Permissions boundary
# Hard ceiling on what the role can ever do
# Explicit denies override any attached policy
# Neither CloudTrail nor snapshots are reachable

resource "aws_iam_policy" "automation_boundary" {
  name        = "AutomationRoleBoundary"
  description = "Maximum permission ceiling for automation role — explicit denies cannot be overridden"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    : "AllowScoped",
        Effect : "Allow",
        Action : [
          "iam:ListUsers",
          "iam:GetUser",
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource : "*"
      },
      {
        Sid    : "DenyCloudTrailModification",
        Effect : "Deny",
        Action : [
          "cloudtrail:StartLogging",
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail",
          "cloudtrail:UpdateTrail"
        ],
        Resource : "*"
      },
      {
        Sid    : "DenySnapshots",
        Effect : "Deny",
        Action : [
          "ec2:CreateSnapshot",
          "ec2:CopySnapshot",
          "ec2:ModifySnapshotAttribute"
        ],
        Resource : "*"
      }
    ]
  })
}

# Automation role
# Assumed by EC2 instance profile, not by human user directly
# In this experiment, it is governed by security and IT and out of reach to the Human IAM user
# Actions are logged under the automation role identity in CloudTrail

resource "aws_iam_role" "automation_role" {
  name                 = "AutomationRole"
  permissions_boundary = aws_iam_policy.automation_boundary.arn
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [{
      Effect : "Allow",
      Principal : { Service : "ec2.amazonaws.com" },
      Action : "sts:AssumeRole"
    }]
  })
  tags = { Purpose = "AutomationPrincipal", RoleType = "ServiceIdentity" }
}

resource "aws_iam_policy" "automation_role_policy" {
  name        = "AutomationRolePolicy"
  description = "Scoped permissions for automation principal — within boundary ceiling"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    : "AllowListUsers",
        Effect : "Allow",
        Action : ["iam:ListUsers", "iam:GetUser"],
        Resource : "*"
      },
      {
        Sid    : "AllowAutomationPrefix",
        Effect : "Allow",
        Action : ["s3:PutObject", "s3:GetObject"],
        Resource : "${aws_s3_bucket.workflow.arn}/automation/*"
      },
      {
        Sid      : "AllowListAutomationPrefix",
        Effect   : "Allow",
        Action   : ["s3:ListBucket"],
        Resource : aws_s3_bucket.workflow.arn,
        Condition : { StringLike : { "s3:prefix" : ["automation/*"] } }
      },
      {
        Sid    : "AllowSecretsAccess",
        Effect : "Allow",
        Action : ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
        Resource : aws_secretsmanager_secret.automation_credentials.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "automation_role_attach" {
  role       = aws_iam_role.automation_role.name
  policy_arn = aws_iam_policy.automation_role_policy.arn
}

resource "aws_iam_instance_profile" "automation_profile" {
  name = "AutomationInstanceProfile"
  role = aws_iam_role.automation_role.name
}
