"""Lambda handler for MediaConvert job completion events via SNS.

Receives SNS notifications from CloudWatch Events when a MediaConvert
job completes (or errors), logs the result, and could be extended to
update a database or notify downstream services.
"""

import json
import os

import boto3


def handler(event, context):
    """Handle SNS notification for MediaConvert job status change.

    Args:
        event: SNS event wrapping a CloudWatch Event for MediaConvert.
        context: Lambda execution context.

    Returns:
        Dictionary with processing status.
    """
    for record in event["Records"]:
        message = json.loads(record["Sns"]["Message"])

        detail = message.get("detail", message)
        job_id = detail.get("jobId", "unknown")
        status = detail.get("status", "unknown")
        output_group = detail.get("outputGroupDetails", [])

        print(f"MediaConvert job {job_id} status: {status}")

        if status == "COMPLETE":
            output_paths = []
            for group in output_group:
                for output_detail in group.get("outputDetails", []):
                    output_uri = output_detail.get("outputFilePaths", [])
                    output_paths.extend(output_uri)

            print(f"Job {job_id} completed. Outputs: {json.dumps(output_paths)}")

        elif status == "ERROR":
            error_code = detail.get("errorCode", "unknown")
            error_message = detail.get("errorMessage", "no details")
            print(f"Job {job_id} failed. Error {error_code}: {error_message}")

        else:
            print(f"Job {job_id} status update: {status}")

    return {
        "statusCode": 200,
        "body": json.dumps({"processed": len(event["Records"])}),
    }
