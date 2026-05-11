# ------------------------------------------------------------------------------
# 1. IAM Policy
# ------------------------------------------------------------------------------

# Create a custom IAM policy that enforces MFA for deleting S3 objects
resource "aws_iam_policy" "mfa_delete_policy" {
  name = "${var.project_name}-mfa-delete-policy"
  description = "Policy that requires MFA to delete S3 objects"

    policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyDeleteWithoutMFA"
        Effect   = "Deny"
        Action   = "s3:DeleteObject"
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

# 2. IAM Policy: Enforce encryptionin transit for S3
resource "aws_iam_policy" "enforce_s3_encryption_transit" {
  name = "${var.project_name}-s3-encryption-transit"
  description = "Deny S3 actions without encryption in transit"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyUnencryptedObjectUploads"
        Effect   = "Deny"
        Action   = "s3:PutObject"
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