# --- Lambda Function for S3 trigger ---

data "archive_file" "lambda_trigger" {
  type        = "zip"
  source_file = "${path.module}/../../lambda/trigger_mediaconvert/handler.py"
  output_path = "${path.module}/../../lambda/trigger_mediaconvert/handler.zip"
}

resource "aws_lambda_function" "trigger_mediaconvert" {
  function_name = "${var.project_name}-trigger-mediaconvert-${var.environment}"
  role          = aws_iam_role.lambda_trigger.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 128

  filename         = data.archive_file.lambda_trigger.output_path
  source_code_hash = data.archive_file.lambda_trigger.output_base64sha256

  environment {
    variables = {
      OUTPUT_BUCKET        = aws_s3_bucket.encrypted_media.id
      MEDIACONVERT_ENDPOINT = var.mediaconvert_endpoint
      MEDIACONVERT_ROLE_ARN = aws_iam_role.mediaconvert.arn
      MEDIACONVERT_QUEUE   = aws_media_convert_queue.ingestion.arn
      HLS_AES_KEY          = var.hls_aes_key
      HLS_KEY_URI          = var.hls_key_uri
    }
  }

  tags = merge(local.common_tags, {
    Name = "Trigger MediaConvert Lambda"
  })
}

# --- S3 Event Notification → Lambda ---

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_mediaconvert.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_media.arn
}

resource "aws_s3_bucket_notification" "raw_media_upload" {
  bucket = aws_s3_bucket.raw_media.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.trigger_mediaconvert.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".mp4"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}
