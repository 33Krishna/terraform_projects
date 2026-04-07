output "website_url" {
  description = "The URL of the static website"
  value       = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}

output "aws_cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.s3_distribution.id
}

output "aws_s3_bucket_name" {
  description = "The Name of the S3 bucket"
  value       = aws_s3_bucket.website_bucket.bucket
}