# ============================================================================
# LAMBDA FUNCTION MODULE — FIXED VERSION
# Changes from original:
#   Bug 1:  logs Resource — wildcard "*:*" → specific log group ARN
#   Imp 1:  s3:PutObjectAcl removed — deprecated in modern S3
#   Imp 2:  cloudwatch:PutMetricData — Condition added for namespace restriction
#   Imp 3:  metric_namespace variable added (see variables.tf)
# ============================================================================

# -----------------------------------------------------------------------------
# IAM ROLE
# Yeh Lambda ki identity hai AWS mein.
# assume_role_policy = "sirf lambda.amazonaws.com service yeh role le sakti hai"
# Koi aur service (EC2, S3) yeh role nahi assume kar sakti — security ke liye.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.function_name}-role"
    }
  )
}

# -----------------------------------------------------------------------------
# IAM POLICY (inline — role pe directly attached)
# Har Statement block ek cheez allow karta hai.
# Least privilege: sirf jo zaroori hai, wahi allow karo.
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.function_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # PERMISSION 1: CloudWatch Logs — Lambda ko apne logs likhne ke liye
      # BUG FIX 1: Resource wildcard "*:*" tha — bahut broad tha
      #   Pehle: "arn:aws:logs:region:*:*" = kisi bhi account ki kisi bhi log group
      #   Ab: sirf is function ki apni log group
      #   ":*" end mein zaroori hai — log streams ke liye (log group ARN + :log-stream:name)
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.lambda_log_group.arn}:*"
        # BUG FIX 1: ab sirf apni log group tak restricted
      },

      # PERMISSION 2: S3 Read — upload bucket se original image padhna
      # Sirf GetObject aur GetObjectVersion — write nahi
      # Resource = bucket ARN + /* = bucket ke andar ki har file
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${var.upload_bucket_arn}/*"
      },

      # PERMISSION 3: S3 Write — processed bucket mein output save karna
      # IMP FIX 1: s3:PutObjectAcl remove kiya
      #   Original mein tha — par 2023 ke baad S3 Object ACLs deprecated hain
      #   Block Public Access settings ne ACLs replace ki hain
      #   Extra permission = extra attack surface — remove karo
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
          # IMP FIX 1: "s3:PutObjectAcl" remove kiya — deprecated, not needed
        ]
        Resource = "${var.processed_bucket_arn}/*"
      },

      # PERMISSION 4: CloudWatch Custom Metrics — Lambda code se metrics push karna
      # Resource = "*" AWS ki limitation hai — PutMetricData resource-level restrict nahi hota
      # IMP FIX 2: Condition add kiya — namespace restrict karta hai
      #   Matlab Lambda sirf "ImageProcessor/Lambda" namespace mein push kar sakti hai
      #   Doosre namespaces mein nahi — agar code compromise ho toh damage limited
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*" # AWS limitation — resource-level not supported for this action
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = var.metric_namespace
            # IMP FIX 2: sirf apne namespace mein metrics push ho sakti hain
          }
        }
      }

    ]
  })
}

# -----------------------------------------------------------------------------
# CLOUDWATCH LOG GROUP
# Lambda ke logs ka ghar — pehle se banana kyun?
#   1. Retention control: AWS auto-create mein retention nahi hoti — logs forever rahenge
#   2. Terraform conflict: Lambda pehle chale toh AWS apna group banata hai,
#      phir Terraform ka apply conflict karta hai
#   3. Tags: pehle se banao toh tags lag jaate hain
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.function_name}-logs"
    }
  )
}

# -----------------------------------------------------------------------------
# LAMBDA FUNCTION
# Actual function resource — code, config, environment sab yahan.
#
# Key fields:
#   filename         = tera zip file ka path (code yahan se load hoga)
#   source_code_hash = zip ka SHA256 hash — code change detect karta hai
#   handler          = "file.function" — kaunsi Python function call karni hai
#   layers           = Pillow library jaisi dependencies (separate zip)
#   depends_on       = pehle log group + policy, phir Lambda
#                      (Terraform parallel banata hai — order enforce karna padta hai)
#
# Environment variables Lambda code ko kaise milte hain:
#   Python mein: import os; bucket = os.environ['PROCESSED_BUCKET']
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "function" {
  filename         = var.lambda_zip_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = var.handler
  source_code_hash = var.source_code_hash
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size

  layers = var.lambda_layers

  environment {
    variables = merge(
      {
        PROCESSED_BUCKET = var.processed_bucket_id
        LOG_LEVEL        = var.log_level
        METRIC_NAMESPACE = var.metric_namespace # added — Lambda code ko namespace pata hoga
      },
      var.environment_variables # root module se extra vars inject ho sakte hain
    )
  }

  tags = merge(
    var.tags,
    {
      Name = var.function_name
    }
  )

  # depends_on zaroori hai:
  # log_group — Lambda pehle chale toh logs kahin nahi jaayenge
  # lambda_policy — pehle permissions, phir function (varna first invocation fail)
  depends_on = [
    aws_cloudwatch_log_group.lambda_log_group,
    aws_iam_role_policy.lambda_policy
  ]
}
