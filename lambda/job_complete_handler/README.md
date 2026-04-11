# Lambda — Job Complete Handler

Receives SNS notifications when MediaConvert jobs complete or fail.

## Flow
1. MediaConvert job finishes (COMPLETE or ERROR)
2. CloudWatch Event Rule captures the status change
3. Event published to SNS topic
4. SNS triggers this Lambda
5. Lambda logs job result (output paths on success, error details on failure)

## Extending
- Add DynamoDB write to track job status per content_id
- Send Slack notification on failure
- Trigger downstream processing on success
