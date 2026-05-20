variable "function_name" {
  description = "Name of the Lambda function to monitor"
  type        = string
}

variable "critical_alerts_topic_arn" {
  description = "ARN of the SNS topic for critical alerts (errors, throttles)"
  type        = string
}

variable "performance_alerts_topic_arn" {
  description = "ARN of the SNS topic for performance alerts (duration, concurrency)"
  type        = string
}

variable "metric_namespace" {
  description = "CloudWatch custom metrics namespace (must match what Lambda/metric filters push to)"
  type        = string
  default     = "ImageProcessor/Lambda"
}

variable "alarm_period" {
  description = "Default period for alarm evaluation in seconds (60 = check every 1 minute)"
  type        = number
  default     = 60
}

# -------------------------------------------------------
# Error Alarm
# -------------------------------------------------------
variable "error_threshold" {
  description = "Number of errors in one period before alarm fires"
  type        = number
  default     = 3
}

variable "error_evaluation_periods" {
  description = "How many consecutive bad periods before alarm fires (1 = fire immediately)"
  type        = number
  default     = 1
}

# -------------------------------------------------------
# Duration Alarm
# -------------------------------------------------------
variable "duration_threshold_ms" {
  description = "Average duration in ms above which alarm fires (default 45s = 75% of 60s timeout)"
  type        = number
  default     = 45000
}

variable "duration_evaluation_periods" {
  description = "Consecutive periods of high duration before alarm fires (2 = 2 minutes sustained)"
  type        = number
  default     = 2
}

# -------------------------------------------------------
# Throttle Alarm
# -------------------------------------------------------
variable "throttle_threshold" {
  description = "Number of throttles in one period before alarm fires"
  type        = number
  default     = 5
}

variable "throttle_evaluation_periods" {
  description = "Consecutive periods of throttling before alarm fires"
  type        = number
  default     = 1
}

# -------------------------------------------------------
# Concurrent Executions Alarm
# -------------------------------------------------------
variable "concurrent_executions_threshold" {
  description = "Max concurrent executions before alarm fires (default 50, AWS default limit is 1000)"
  type        = number
  default     = 50
}

# -------------------------------------------------------
# Log Error Alarm
# -------------------------------------------------------
variable "log_error_threshold" {
  description = "Number of ERROR log lines in 60s before alarm fires (1 = any single error)"
  type        = number
  default     = 1
}

# -------------------------------------------------------
# Success Rate Alarm
# -------------------------------------------------------
variable "min_success_threshold" {
  description = "Minimum successful image processes expected per 5-minute window"
  type        = number
  default     = 1
}

# -------------------------------------------------------
# No Invocations Alarm
# -------------------------------------------------------
variable "enable_no_invocation_alarm" {
  description = "Set to true to enable the silent-trigger detector alarm"
  type        = bool
  default     = false
}

# BUG FIX 3: this variable did not exist in the original
# no_invocations alarm had evaluation_periods = 3 hardcoded
# Now it reads from here — consistent with every other alarm in this module
variable "no_invocation_evaluation_periods" {
  description = "How many 5-minute periods with zero invocations before alarm fires (default 3 = 15 min silence)"
  type        = number
  default     = 3
}

# -------------------------------------------------------
# Common Tags
# -------------------------------------------------------
variable "tags" {
  description = "Tags to merge onto every alarm resource (e.g. env, project, team)"
  type        = map(string)
  default     = {}
}
