# ------------------------------------------------------------------------------
# IAM Policies
# ------------------------------------------------------------------------------

# 1. Create a custom IAM policy that enforces MFA for deleting S3 objects
# FIX: BoolIfExists + Bool dono statements add kiye
# Pehle sirf BoolIfExists tha — MFA key missing hone pe allow ho jaata tha
resource "aws_iam_policy" "mfa_delete_policy" {
  name = "${var.project_name}-mfa-delete-policy"
  description = "Policy that requires MFA to delete S3 objects"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Case 1: MFA key exist karti hai aur false hai → DENY
        Sid      = "DenyDeleteWithoutMFA"
        Effect   = "Deny"
        Action   = "s3:DeleteObject"
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      },
      {
        # Case 2: MFA key exist hi nahi karti (normal login) → bhi DENY
        Sid      = "DenyDeleteIfNoMFAKey"
        Effect   = "Deny"
        Action   = "s3:DeleteObject"
        Resource = "*"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

# 2. IAM Policy: Enforce encryptionin transit for S3
# FIX: Action "s3:*" rakha — pehle sirf PutObject tha
# GET, DELETE bhi HTTP se ho sakta tha — ab sab block
resource "aws_iam_policy" "enforce_s3_encryption_transit" {
  name        = "${var.project_name}-s3-encryption-transit"
  description = "Deny all S3 actions without encryption in transit"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyUnencryptedTransport"
        Effect   = "Deny"
        Action   = "s3:*"
        Resource = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Policy 3: Require Tags Policy
# FIX: Yeh policy outputs.tf mein reference thi but bani nahi thi
resource "aws_iam_policy" "require_tags_policy" {
  name        = "${var.project_name}-require-tags-policy"
  description = "Deny EC2 launch without required tags"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyEC2WithoutTags"
        Effect   = "Deny"
        Action   = "ec2:RunInstances"
        Resource = "*"
        Condition = {
          # Agar Environment tag null hai (missing) → DENY
          "Null" = {
            "aws:RequestTag/Environment" = "true"
            "aws:RequestTag/Owner"       = "true"
          }
        }
      }
    ]
  })
}


# ------------------------------------------------------------------------------
# IAM Group — Group Approach
# FIX: Pehle policy directly user pe attach thi
#      Ab group pe attach hai
#      Naya user aaye → sirf group mein daalo → saari policies auto-apply
# ------------------------------------------------------------------------------

resource "aws_iam_group" "security_group" {
  name = "${var.project_name}-security-group"
}

# Saari policies GROUP pe attach karo (user pe nahi)
resource "aws_iam_group_policy_attachment" "attach_mfa_to_group" {
  group      = aws_iam_group.security_group.name
  policy_arn = aws_iam_policy.mfa_delete_policy.arn
}

resource "aws_iam_group_policy_attachment" "attach_encryption_to_group" {
  group      = aws_iam_group.security_group.name
  policy_arn = aws_iam_policy.enforce_s3_encryption_transit.arn
}

resource "aws_iam_group_policy_attachment" "attach_tags_to_group" {
  group      = aws_iam_group.security_group.name
  policy_arn = aws_iam_policy.require_tags_policy.arn
}

# ------------------------------------------------------------------------------
# Demo IAM User
# FIX: Yeh bhi outputs mein tha but bana nahi tha
# ------------------------------------------------------------------------------

resource "aws_iam_user" "demo_user" {
  name = "${var.project_name}-demo-user"

  tags = {
    Environment = "governance"
    Owner       = "terraform-demo"
    ManagedBy   = "terraform"
  }
}

# Demo user ko group mein daalo
# Group mein daalne se saari policies auto-apply hongi
resource "aws_iam_user_group_membership" "demo_user_group" {
  user   = aws_iam_user.demo_user.name
  groups = [aws_iam_group.security_group.name]
}

# ------------------------------------------------------------------------------
# IAM Role for AWS Config Recorder
# Config ko permission chahiye resources scan karne ki
# ------------------------------------------------------------------------------

resource "aws_iam_role" "config_recorder_role" {
  name = "${var.project_name}-config-recorder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = "governance"
    ManagedBy   = "terraform"
  }
}

# AWS managed policy — Config ko AWS resources read karne ki permission
resource "aws_iam_role_policy_attachment" "config_role_policy" {
  role       = aws_iam_role.config_recorder_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}
