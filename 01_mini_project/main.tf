# S3 Bucket for Static Website
resource "aws_s3_bucket" "website_bucket" {
  bucket = "${var.bucket_prefix}-${random_id.r_id.hex}"

  tags = {
    Name        = "${var.bucket_prefix}-${random_id.r_id.hex}"
    Environment = var.environment
    Owner       = "krishna"
  }
}

# Random ID for S3 Bucket
resource "random_id" "r_id" {
  byte_length = 8
}

#S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "website_bucket_versioning" {
  bucket = aws_s3_bucket.website_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "website_bucket_public_access_block" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Origin Access Control for CloudFront (Recommended over OAI)
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "oac-${var.bucket_prefix}"
  description                       = "OAC for static website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  depends_on = [ aws_s3_bucket_public_access_block.website_bucket_public_access_block ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "${aws_cloudfront_distribution.s3_distribution.arn}"
          }
        }
      }
    ]
  })
}

# Upload website files to S3
resource "aws_s3_object" "website_bucket_object" {
  for_each = fileset("${path.module}/www", "**/*")

  bucket = aws_s3_bucket.website_bucket.id
  key    = each.value
  source = "${path.module}/www/${each.value}"
  etag = filemd5("${path.module}/www/${each.value}")

  content_type = lookup({
    "html" = "text/html",
    "css"  = "text/css",
    "js"   = "application/javascript",
    "json" = "application/json",
    "png"  = "image/png",
    "jpg"  = "image/jpeg",
    "jpeg" = "image/jpeg",
    "gif"  = "image/gif",
    "svg"  = "image/svg+xml",
    "ico"  = "image/x-icon",
    "txt"  = "text/plain"
  }, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
}


# CloudFront Distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.website_bucket.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Without Custom Domain
  # viewer_certificate {
  #   cloudfront_default_certificate = true
  # }

  # With Custom Domain [ Here cloudfront bolta hai ki certificate use karo HTTPS ke liye like SSL Attach karke ]
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert_validation.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/error.html"
    error_caching_min_ttl = 300
  }
}

# ACM Certificate (Here we create our certificate)
resource "aws_acm_certificate" "cert" {
  domain_name = var.domain_name
  validation_method = "DNS"

  # Certificate ko destroy hone se pehle new certificate create karo for Zero Downtime
  lifecycle {
    create_before_destroy = true
  }
}

# Route53 ( Custom Domain ) [ Mere domain ka DNS manage karo mtlb hosted zone create karo ]
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# Route53 Record for ACM Certificate Validation [ Idhar ACM Bolta hai prove karo domain tera hai ]
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options :
    dvo.domain_name => dvo
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60
}

# ACM Certificate Validation [ Dns record ko validate karo and certificate ko active karo ]
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# CloudFront Response Headers Policy [ Security Headers, Browser ko instructions dena ki website ko safe kaise handle kare ] 
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "security-headers"

  security_headers_config {
    # protect from fake file execution [Sirf jo type diya hai wahi use kar]
    content_type_options { override = true }

    # protect from clickjacking attack [frame ko block kar, Kisi bhi iframe me load mat ho]
    frame_options {
      frame_option = "DENY"
      override     = true
    }

    # protect from leaking sensitive data to other sites [Referrer ko hide kar, data leak nhi hoga]
    referrer_policy {
      referrer_policy = "no-referrer"
      override        = true
    }

    # protect from XSS attack [Cross-Site Scripting ko block kar, Agar suspicious script hai → block karo]
    xss_protection {
      protection = true
      mode_block = true
      override   = true
    }
  }
}