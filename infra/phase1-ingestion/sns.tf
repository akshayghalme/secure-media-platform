# --- SNS Topic for MediaConvert Job Completion ---

resource "aws_sns_topic" "mediaconvert_notifications" {
  name = "${var.project_name}-mediaconvert-notifications-${var.environment}"

  tags = merge(local.common_tags, {
    Name = "MediaConvert Notifications"
  })
}

resource "aws_sns_topic_policy" "mediaconvert_notifications" {
  arn = aws_sns_topic.mediaconvert_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventsPublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.mediaconvert_notifications.arn
      }
    ]
  })
}

# --- CloudWatch Event Rule for MediaConvert Status Changes ---

resource "aws_cloudwatch_event_rule" "mediaconvert_job_status" {
  name        = "${var.project_name}-mediaconvert-job-status-${var.environment}"
  description = "Captures MediaConvert job state changes (COMPLETE, ERROR)"

  event_pattern = jsonencode({
    source      = ["aws.mediaconvert"]
    detail-type = ["MediaConvert Job State Change"]
    detail = {
      status = ["COMPLETE", "ERROR"]
    }
  })

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "mediaconvert_to_sns" {
  rule = aws_cloudwatch_event_rule.mediaconvert_job_status.name
  arn  = aws_sns_topic.mediaconvert_notifications.arn
}

# --- Job Complete Handler Lambda ---

resource "aws_iam_role" "job_complete_handler" {
  name = "${var.project_name}-job-complete-handler-${var.environment}"

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
    Name = "Job Complete Handler Role"
  })
}

resource "aws_iam_role_policy_attachment" "job_complete_handler_logs" {
  role       = aws_iam_role.job_complete_handler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "job_complete_handler" {
  type        = "zip"
  source_file = "${path.module}/../../lambda/job_complete_handler/handler.py"
  output_path = "${path.module}/../../lambda/job_complete_handler/handler.zip"
}

resource "aws_lambda_function" "job_complete_handler" {
  function_name = "${var.project_name}-job-complete-handler-${var.environment}"
  role          = aws_iam_role.job_complete_handler.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  timeout       = 15
  memory_size   = 128

  filename         = data.archive_file.job_complete_handler.output_path
  source_code_hash = data.archive_file.job_complete_handler.output_base64sha256

  tags = merge(local.common_tags, {
    Name = "Job Complete Handler Lambda"
  })
}

# --- SNS → Lambda Subscription ---

resource "aws_lambda_permission" "sns_invoke_job_complete" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.job_complete_handler.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.mediaconvert_notifications.arn
}

resource "aws_sns_topic_subscription" "job_complete_lambda" {
  topic_arn = aws_sns_topic.mediaconvert_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.job_complete_handler.arn
}
