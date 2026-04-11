# --- Lambda Execution Role ---
# Used by the S3-triggered Lambda that submits MediaConvert jobs

resource "aws_iam_role" "lambda_trigger" {
  name = "${var.project_name}-lambda-trigger-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "Lambda Trigger Role"
  })
}

# CloudWatch Logs — Lambda needs to write logs
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_trigger.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda policy — read raw bucket, submit MediaConvert jobs, pass MediaConvert role
resource "aws_iam_policy" "lambda_trigger" {
  name        = "${var.project_name}-lambda-trigger-policy-${var.environment}"
  description = "Allows Lambda to read raw S3 bucket, submit MediaConvert jobs, and pass the MediaConvert role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadRawBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.raw_media.arn,
          "${aws_s3_bucket.raw_media.arn}/*"
        ]
      },
      {
        Sid    = "SubmitMediaConvertJob"
        Effect = "Allow"
        Action = [
          "mediaconvert:CreateJob",
          "mediaconvert:GetJob",
          "mediaconvert:ListJobs",
          "mediaconvert:DescribeEndpoints"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassMediaConvertRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.mediaconvert.arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_trigger" {
  role       = aws_iam_role.lambda_trigger.name
  policy_arn = aws_iam_policy.lambda_trigger.arn
}

# --- MediaConvert Role ---
# Used by MediaConvert to read from raw bucket and write encrypted output

resource "aws_iam_role" "mediaconvert" {
  name = "${var.project_name}-mediaconvert-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "mediaconvert.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "MediaConvert Role"
  })
}

resource "aws_iam_policy" "mediaconvert" {
  name        = "${var.project_name}-mediaconvert-policy-${var.environment}"
  description = "Allows MediaConvert to read raw media and write encrypted output"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadRawBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.raw_media.arn,
          "${aws_s3_bucket.raw_media.arn}/*"
        ]
      },
      {
        Sid    = "WriteEncryptedBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.encrypted_media.arn,
          "${aws_s3_bucket.encrypted_media.arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "mediaconvert" {
  role       = aws_iam_role.mediaconvert.name
  policy_arn = aws_iam_policy.mediaconvert.arn
}
