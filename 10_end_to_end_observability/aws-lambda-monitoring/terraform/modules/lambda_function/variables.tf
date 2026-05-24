# ============================================================================
# LAMBDA FUNCTION MODULE — variables.tf FIXED VERSION
# Change from original: metric_namespace variable added
#   Needed for IMP FIX 2 (CloudWatch PutMetricData Condition)
#   and to pass namespace to Lambda environment variables
# ============================================================================

# --- Required variables (no default — must be passed from root module) ------

variable "function_name" {
  description = "Name of the Lambda function — used as prefix for all resources"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to Lambda function zip file — relative to terraform root"
  type        = string
}

variable "source_code_hash" {
  description = "Base64 SHA256 hash of zip — Terraform uses this to detect code changes"
  type        = string
}

variable "upload_bucket_arn" {
  description = "ARN of upload S3 bucket — used in IAM policy for read permission"
  type        = string
}

variable "upload_bucket_id" {
  description = "ID (name) of upload bucket — passed as env var if Lambda needs it"
  type        = string
}

variable "processed_bucket_arn" {
  description = "ARN of processed S3 bucket — used in IAM policy for write permission"
  type        = string
}

variable "processed_bucket_id" {
  description = "ID (name) of processed bucket — passed as PROCESSED_BUCKET env var to Lambda code"
  type        = string
}

variable "aws_region" {
  description = "AWS region — used in IAM resource ARNs"
  type        = string
}

# --- Optional variables (have defaults — override if needed) ----------------

variable "handler" {
  description = "Lambda handler in format 'filename.function_name' (Python: lambda_function.lambda_handler)"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "runtime" {
  description = "Lambda runtime identifier"
  type        = string
  default     = "python3.12"
}

variable "timeout" {
  description = "Lambda timeout in seconds — max 900. Default 60s for image processing."
  type        = number
  default     = 60
}

variable "memory_size" {
  description = "Lambda memory in MB — CPU also scales with memory. 1024MB good for image processing."
  type        = number
  default     = 1024
}

variable "lambda_layers" {
  description = "List of Lambda layer ARNs (e.g. Pillow image library layer)"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days — controls cost. 7=dev, 30=staging, 90=prod."
  type        = number
  default     = 7
}

variable "log_level" {
  description = "Log level passed as LOG_LEVEL env var to Lambda (DEBUG/INFO/WARNING/ERROR)"
  type        = string
  default     = "INFO"
}

# IMP FIX 3: new variable — was missing in original
# Used in:
#   1. IAM Condition — restrict PutMetricData to this namespace only
#   2. Lambda env var METRIC_NAMESPACE — Lambda code ko pata ho kahan push karna hai
variable "metric_namespace" {
  description = "CloudWatch custom metrics namespace — must match cloudwatch_metrics module"
  type        = string
  default     = "ImageProcessor/Lambda"
}

variable "environment_variables" {
  description = "Additional env vars to inject into Lambda — merged with module defaults"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources — use for env, project, team, cost-center"
  type        = map(string)
  default     = {}
}
