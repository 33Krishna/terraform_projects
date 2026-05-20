# ============================================================================
# CLOUDWATCH ALARMS MODULE
# Creates CloudWatch alarms for Lambda function monitoring
# ============================================================================

# -----------------------------------------------------------------------------
# ALARM 1: Lambda Error Rate
# Watches: AWS built-in "Errors" metric
# Fires when: more than var.error_threshold errors in one 60s period
# Goes to: CriticalSNS — because errors mean users are getting failures
# Statistic = Sum because we want TOTAL errors, not average
# ok_actions = same topic so you also get notified when it recovers
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.function_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.error_evaluation_periods
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.alarm_period
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "Triggers when Lambda function has more than ${var.error_threshold} errors"
  actions_enabled     = true
  alarm_actions       = [var.critical_alerts_topic_arn]
  ok_actions          = [var.critical_alerts_topic_arn]

  dimensions = {
    FunctionName = var.function_name
  }

  tags = merge(
    var.tags,
    {
      Name     = "${var.function_name}-error-alarm"
      Severity = "Critical"
    }
  )
}

# -----------------------------------------------------------------------------
# ALARM 2: Lambda Duration (Timeout Warning)
# Watches: AWS built-in "Duration" metric
# Fires when: average duration > 45,000ms (= 45 seconds, which is 75% of 60s timeout)
# Goes to: PerformanceSNS — not crashing yet, but will soon if not fixed
# Statistic = Average because one slow run is fine, a trend of slow runs is not
# evaluation_periods = 2 means: must be slow for 2 consecutive minutes before alert
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.function_name}-high-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.duration_evaluation_periods
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.duration_threshold_ms
  alarm_description   = "Triggers when Lambda duration exceeds ${var.duration_threshold_ms}ms (approaching timeout)"
  actions_enabled     = true
  alarm_actions       = [var.performance_alerts_topic_arn]
  ok_actions          = [var.performance_alerts_topic_arn]

  dimensions = {
    FunctionName = var.function_name
  }

  tags = merge(
    var.tags,
    {
      Name     = "${var.function_name}-duration-alarm"
      Severity = "Warning"
    }
  )
}

# -----------------------------------------------------------------------------
# ALARM 3: Lambda Throttles
# Watches: AWS built-in "Throttles" metric
# Fires when: AWS rejects more than var.throttle_threshold requests
# Goes to: CriticalSNS — throttles mean requests are being DROPPED completely
# Why throttles happen: you hit AWS Lambda concurrency limit for your account
# Statistic = Sum because each throttle = one user request rejected
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.function_name}-high-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.throttle_evaluation_periods
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = var.alarm_period
  statistic           = "Sum"
  threshold           = var.throttle_threshold
  alarm_description   = "Triggers when Lambda function is throttled (concurrent execution limit reached)"
  actions_enabled     = true
  alarm_actions       = [var.critical_alerts_topic_arn]
  ok_actions          = [var.critical_alerts_topic_arn]

  dimensions = {
    FunctionName = var.function_name
  }

  tags = merge(
    var.tags,
    {
      Name     = "${var.function_name}-throttle-alarm"
      Severity = "Critical"
    }
  )
}

# -----------------------------------------------------------------------------
# ALARM 4: Concurrent Executions
# Watches: AWS built-in "ConcurrentExecutions" metric
# Fires when: more than var.concurrent_executions_threshold running at same time
# Goes to: PerformanceSNS — high concurrency = approaching throttle limit (alarm 3)
# Statistic = Maximum because peak value matters, not average
#             (even 1 second of 200 concurrent = risk of hitting limit)
# evaluation_periods = 2 to avoid false alarms from short spikes
#
# BUG FIX 1 (original had no ok_actions):
#   Added ok_actions so you get notified when concurrency drops back to normal.
#   Without this, alarm goes red and you never know when it recovered.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "concurrent_executions" {
  alarm_name          = "${var.function_name}-high-concurrency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ConcurrentExecutions"
  namespace           = "AWS/Lambda"
  period              = var.alarm_period
  statistic           = "Maximum"
  threshold           = var.concurrent_executions_threshold
  alarm_description   = "Triggers when concurrent executions exceed ${var.concurrent_executions_threshold}"
  actions_enabled     = true
  alarm_actions       = [var.performance_alerts_topic_arn]
  ok_actions          = [var.performance_alerts_topic_arn]  # BUG FIX 1: was missing

  dimensions = {
    FunctionName = var.function_name
  }

  tags = merge(
    var.tags,
    {
      Name     = "${var.function_name}-concurrency-alarm"
      Severity = "Warning"
    }
  )
}

# -----------------------------------------------------------------------------
# ALARM 5: Custom Error Metric from Logs
# Watches: CUSTOM metric "LambdaErrors" in "ImageProcessor/Lambda" namespace
# This metric is created by a CloudWatch Metric Filter scanning your log group
# Fires when: even 1 ERROR log line appears in 60s
# Goes to: CriticalSNS
# treat_missing_data = "notBreaching" — if no logs came in, assume OK
#   (because Lambda wasn't even invoked, not because errors are hidden)
#
# BUG FIX 2 (original had no dimensions block):
#   Added dimensions so this alarm is tied to your specific function.
#   Without this, if you have multiple functions with same metric filter name,
#   all their errors get counted together — impossible to debug which one failed.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "log_errors" {
  alarm_name          = "${var.function_name}-log-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "LambdaErrors"
  namespace           = var.metric_namespace
  period              = 60
  statistic           = "Sum"
  threshold           = var.log_error_threshold
  alarm_description   = "Triggers when ERROR logs are detected in Lambda function"
  actions_enabled     = true
  alarm_actions       = [var.critical_alerts_topic_arn]
  treat_missing_data  = "notBreaching"

  # BUG FIX 2: was missing — ties this alarm to the specific function
  dimensions = {
    FunctionName = var.function_name
  }

  tags = merge(
    var.tags,
    {
      Name     = "${var.function_name}-log-error-alarm"
      Severity = "Critical"
    }
  )
}

# -----------------------------------------------------------------------------
# ALARM 6: No Invocations (Dead trigger detector) — OPTIONAL
# Watches: AWS built-in "Invocations" metric
# Fires when: zero invocations for 3 consecutive 5-minute periods = 15 minutes silent
# Goes to: PerformanceSNS
# comparison_operator = LessThanThreshold — fires when count DROPS below 1
# treat_missing_data = "breaching" — no data at all = assume the trigger broke
#   (opposite of log_errors: silence here means something is wrong)
#
# BUG FIX 3 (original had hardcoded evaluation_periods = 3):
#   Changed to var.no_invocation_evaluation_periods (new variable added in variables.tf)
#   Everything else in this module uses variables — hardcoding one was inconsistent
#   and makes it impossible to tune without editing this file directly.
#
# ALSO FIXED: added ok_actions — same missing pattern as alarm 4
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "no_invocations" {
  count               = var.enable_no_invocation_alarm ? 1 : 0
  alarm_name          = "${var.function_name}-no-invocations"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.no_invocation_evaluation_periods  # BUG FIX 3: was hardcoded 3
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggers when Lambda has no invocations for 15 minutes (possible S3 trigger issue)"
  actions_enabled     = true
  alarm_actions       = [var.performance_alerts_topic_arn]
  ok_actions          = [var.performance_alerts_topic_arn]  # also added: was missing
  treat_missing_data  = "breaching"

  dimensions = {
    FunctionName = var.function_name
  }

  tags = merge(
    var.tags,
    {
      Name     = "${var.function_name}-no-invocation-alarm"
      Severity = "Info"
    }
  )
}

# -----------------------------------------------------------------------------
# ALARM 7: Low Success Rate (Business Metric)
# Watches: CUSTOM metric "SuccessfulProcesses" — pushed by your Lambda code itself
# Fires when: successful image processes drop below var.min_success_threshold
# Goes to: PerformanceSNS
# comparison_operator = LessThanThreshold — fires when count is too LOW
# This is a business-level alarm — not "did Lambda crash" but "did the job get done"
# A Lambda can run without errors but still fail to process the image correctly
#
# IMPROVEMENT (original had no treat_missing_data):
#   Added treat_missing_data = "notBreaching"
#   Without this: on cold start or low-traffic periods with no invocations,
#   CloudWatch sees no data, treats it as 0 successes, and fires the alarm
#   immediately — a false positive on every quiet period.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "low_success_rate" {
  alarm_name          = "${var.function_name}-low-success-rate"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "SuccessfulProcesses"
  namespace           = var.metric_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = var.min_success_threshold
  alarm_description   = "Triggers when successful image processes are below expected rate"
  actions_enabled     = true
  alarm_actions       = [var.performance_alerts_topic_arn]
  ok_actions          = [var.performance_alerts_topic_arn]
  treat_missing_data  = "notBreaching"  # IMPROVEMENT: was missing, caused false alarms

  tags = merge(
    var.tags,
    {
      Name     = "${var.function_name}-success-rate-alarm"
      Severity = "Warning"
    }
  )
}
