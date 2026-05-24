# ============================================================================
# CLOUDWATCH METRICS MODULE — FIXED VERSION
# Changes from original:
#   Bug 1: Custom metric widgets — added dimensions block (widgets 4, 5, 6)
#   Bug 2: outputs.tf — s3_access_denied filter output was missing
#   Imp 1: processing_time + image_size filters — removed default_value = "0"
#   Imp 2: Dashboard log widget — added comment to prevent future overlap
#   Imp 3: Dashboard resource does not support tags, so tags block was omitted
# ============================================================================

# -----------------------------------------------------------------------------
# FILTER 1: Lambda Errors
# Pattern: log line ka 3rd field (level) ERROR se shuru hona chahiye
# value = "1" — count karo, actual value nahi chahiye
# default_value = "0" RAKHTE HAIN — kyunki yeh count metric hai
#   no errors = 0 is correct. Wrong hota agar Average use karte.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "lambda_errors" {
  name           = "${var.function_name}-error-count"
  log_group_name = var.log_group_name
  pattern        = "[timestamp, request_id, level = ERROR*, ...]"

  metric_transformation {
    name          = "LambdaErrors"
    namespace     = var.metric_namespace
    value         = "1"
    default_value = "0"
  }
}

# -----------------------------------------------------------------------------
# FILTER 2: Image Processing Time
# Pattern: log line mein "processing_time:" ke baad number ho
# value = "$processing_time" — actual number extract karo log se
#
# IMP FIX 1: default_value = "0" REMOVE kiya
#   Original mein "0" tha — matlab jab koi image process nahi hui,
#   CloudWatch mein 0ms push hota tha.
#   Phir Average = (real_values + many zeros) / total = artificially low number.
#   No default_value = no datapoint when no match = correct Average.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "processing_time" {
  name           = "${var.function_name}-processing-time"
  log_group_name = var.log_group_name
  pattern        = "[timestamp, request_id, level, message, processing_time_key = \"processing_time:\", processing_time, ...]"

  metric_transformation {
    name      = "ImageProcessingTime"
    namespace = var.metric_namespace
    value     = "$processing_time"
    unit      = "Milliseconds"
    # IMP FIX 1: removed default_value = "0" — Average metric pe false low value aata tha
  }
}

# -----------------------------------------------------------------------------
# FILTER 3: Successful Processes
# Pattern: exact string "Successfully processed" log mein ho
# Double quotes = exact phrase match (single word match se alag)
# value = "1" — count karo
# default_value = "0" RAKHTE HAIN — no success = 0 is correct for count
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "successful_processes" {
  name           = "${var.function_name}-success-count"
  log_group_name = var.log_group_name
  pattern        = "\"Successfully processed\""

  metric_transformation {
    name          = "SuccessfulProcesses"
    namespace     = var.metric_namespace
    value         = "1"
    default_value = "0"
  }
}

# -----------------------------------------------------------------------------
# FILTER 4: Image Size
# Pattern: log mein "image_size:" ke baad number ho
# value = "$image_size" — actual bytes value extract karo
#
# IMP FIX 1 (same as filter 2): default_value = "0" REMOVE kiya
#   0 bytes average mein include hona misleading hai
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "image_size" {
  name           = "${var.function_name}-image-size"
  log_group_name = var.log_group_name
  pattern        = "[timestamp, request_id, level, message, size_key = \"image_size:\", image_size, ...]"

  metric_transformation {
    name      = "ImageSizeBytes"
    namespace = var.metric_namespace
    value     = "$image_size"
    unit      = "Bytes"
    # IMP FIX 1: removed default_value = "0"
  }
}

# -----------------------------------------------------------------------------
# FILTER 5: S3 Access Denied
# Pattern: kahin bhi "AccessDenied" word ho — simple keyword scan
# value = "1" — count karo
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "s3_access_denied" {
  name           = "${var.function_name}-s3-denied"
  log_group_name = var.log_group_name
  pattern        = "AccessDenied"

  metric_transformation {
    name          = "S3AccessDenied"
    namespace     = var.metric_namespace
    value         = "1"
    default_value = "0"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard
# Grid system: 24 columns wide, rows expand downward
# x = column start (0-23), y = row start, width + height = size
#
# Layout:
#   Row 0  (y=0):  [Invocations & Errors w=12] [Duration w=12]
#   Row 6  (y=6):  [Concurrent Exec w=12]       [Custom Errors vs Success w=12]
#   Row 12 (y=12): [Processing Time w=12]        [Image Size w=12]
#   Row 18 (y=18): [Recent Errors Log — full width w=24]
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "lambda_monitoring" {
  count          = var.enable_dashboard ? 1 : 0
  dashboard_name = "${var.function_name}-monitoring"

  dashboard_body = jsonencode({
    widgets = [

      # WIDGET 1: Invocations, Errors, Throttles
      # AWS/Lambda namespace — built-in metrics, auto-collected
      # dimensions tied to this specific function
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.function_name, { stat = "Sum", label = "Total Invocations" }],
            [".", "Errors", ".", ".", { stat = "Sum", label = "Errors" }],
            [".", "Throttles", ".", ".", { stat = "Sum", label = "Throttles" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Invocations & Errors"
          period  = 300
        }
        width  = 12
        height = 6
        x      = 0
        y      = 0
      },

      # WIDGET 2: Duration — Avg, Max, P99
      # P99 = 99th percentile: 99% of requests completed within this time
      # More useful than Average for catching tail latency problems
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.function_name, { stat = "Average", label = "Avg Duration" }],
            ["...", { stat = "Maximum", label = "Max Duration" }],
            ["...", { stat = "p99", label = "P99 Duration" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Duration (ms)"
          period  = 300
          yAxis = {
            left = { min = 0 }
          }
        }
        width  = 12
        height = 6
        x      = 12
        y      = 0
      },

      # WIDGET 3: Concurrent Executions
      # Maximum statistic — peak matters, not average
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", var.function_name, { stat = "Maximum", label = "Concurrent Executions" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Concurrent Executions"
          period  = 300
        }
        width  = 12
        height = 6
        x      = 0
        y      = 6
      },

      # WIDGET 4: Custom Metrics — Errors vs Success
      # BUG FIX 1: added "FunctionName", var.function_name dimension
      # Original had no dimensions — all functions' data merged together
      {
        type = "metric"
        properties = {
          metrics = [
            [var.metric_namespace, "LambdaErrors", "FunctionName", var.function_name, { stat = "Sum", label = "Log Errors" }],
            [".", "SuccessfulProcesses", ".", ".", { stat = "Sum", label = "Successful" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Custom Metrics: Errors vs Success"
          period  = 300
          # BUG FIX 1: dimensions block was missing in original
        }
        width  = 12
        height = 6
        x      = 12
        y      = 6
      },

      # WIDGET 5: Image Processing Time
      # BUG FIX 1: added FunctionName dimension inline
      {
        type = "metric"
        properties = {
          metrics = [
            [var.metric_namespace, "ImageProcessingTime", "FunctionName", var.function_name, { stat = "Average", label = "Avg Processing Time" }],
            [".", ".", ".", ".", { stat = "Maximum", label = "Max Processing Time" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Image Processing Time (ms)"
          period  = 300
        }
        width  = 12
        height = 6
        x      = 0
        y      = 12
      },

      # WIDGET 6: Image Size
      # BUG FIX 1: added FunctionName dimension inline
      {
        type = "metric"
        properties = {
          metrics = [
            [var.metric_namespace, "ImageSizeBytes", "FunctionName", var.function_name, { stat = "Average", label = "Avg Image Size" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Image Size (Bytes)"
          period  = 300
        }
        width  = 12
        height = 6
        x      = 12
        y      = 12
      },

      # WIDGET 7: Recent Errors — Live Log Query
      # Type = "log" not "metric" — runs CloudWatch Logs Insights query
      # IMP FIX 2: added comment — do not place other widgets at y=18
      # This is full width (24) — placing anything else at y=18 causes overlap
      {
        type = "log"
        properties = {
          query  = "SOURCE '${var.log_group_name}'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20"
          region = var.aws_region
          title  = "Recent Errors (Live Log Query)"
        }
        width  = 24 # IMP FIX 2: full width row — do not add widgets at y=18
        height = 6
        x      = 0
        y      = 18
      }

    ]
  })
}
