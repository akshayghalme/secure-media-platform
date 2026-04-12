# --- Origin Access Control (OAC) ---
# WHY OAC over the legacy OAI: OAC uses SigV4, supports KMS-encrypted
# buckets, and is the AWS-recommended approach since 2022. OAI is
# deprecated and cannot sign requests for SSE-KMS objects.
resource "aws_cloudfront_origin_access_control" "encrypted_media" {
  name                              = "${var.project_name}-oac-${var.environment}"
  description                       = "OAC for encrypted media bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- Public key + key group for signed URLs ---
# WHY signed URLs: Every HLS .m3u8 and .ts fetch must be authorized to a
# specific user/session with a short expiry. The license server signs the
# manifest URL using the PRIVATE key; CloudFront verifies with the public
# key in this key group. Without this, anyone with the URL could stream.
resource "aws_cloudfront_public_key" "signer" {
  name        = "${var.project_name}-signer-${var.environment}"
  comment     = "Public key for verifying signed URLs"
  encoded_key = var.cloudfront_public_key_pem
}

resource "aws_cloudfront_key_group" "signers" {
  name    = "${var.project_name}-key-group-${var.environment}"
  comment = "Key group for signed URL verification"
  items   = [aws_cloudfront_public_key.signer.id]
}

# --- Distribution ---
resource "aws_cloudfront_distribution" "media" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} media distribution (${var.environment})"
  price_class         = var.price_class
  default_root_object = ""

  origin {
    domain_name              = data.aws_s3_bucket.encrypted_media.bucket_regional_domain_name
    origin_id                = "s3-encrypted-media"
    origin_access_control_id = aws_cloudfront_origin_access_control.encrypted_media.id
  }

  default_cache_behavior {
    # WHY HTTPS-only: playback over plain HTTP would leak the signed URL
    # (including the signature) to any on-path observer.
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-encrypted-media"
    compress               = true

    # WHY trusted_key_groups: this is what makes the distribution REQUIRE
    # a valid signature on every request. Without at least one entry here,
    # CloudFront happily serves the manifest to anyone.
    trusted_key_groups = [aws_cloudfront_key_group.signers.id]

    # WHY CachingOptimized managed policy (ID below): HLS segments are
    # immutable once published, so we want aggressive caching at edge.
    # Using the managed policy avoids hand-rolling forwarded-headers lists.
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    min_ttl     = 0
    default_ttl = var.default_ttl_seconds
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction {
      # WHY none by default: geo-blocking is a business decision per title.
      # Wire this to a per-content allow-list in the license server later.
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # WHY default cert: until a custom domain + ACM cert is wired up
    # (phase4-hls-player task), the cloudfront.net domain serves fine.
    cloudfront_default_certificate = true
  }

  # WHY logging off for now: CloudFront standard logs need a dedicated S3
  # bucket with ACLs enabled, which conflicts with phase1's block-public
  # posture. Real-time logs via Kinesis come in the observability task.
  tags = merge(local.common_tags, {
    Name = "Media CDN"
  })
}

# --- Bucket policy: allow CloudFront OAC to read ---
# WHY this resource lives in phase4: CloudFront is the only entity besides
# the license server and MediaConvert that should read the encrypted bucket.
# This policy REPLACES the phase1 encrypted_media bucket policy — the
# operator must `terraform state rm` that resource in phase1 before
# applying phase4. See README for the exact command.
resource "aws_s3_bucket_policy" "encrypted_media" {
  bucket = data.aws_s3_bucket.encrypted_media.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          data.aws_s3_bucket.encrypted_media.arn,
          "${data.aws_s3_bucket.encrypted_media.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "AllowCloudFrontOACRead"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${data.aws_s3_bucket.encrypted_media.arn}/*"
        # WHY this condition: scopes the grant to THIS distribution only.
        # Without it any CloudFront distribution in any AWS account could
        # read the bucket via OAC, which is a cross-account data leak.
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.media.arn
          }
        }
      }
    ]
  })
}
