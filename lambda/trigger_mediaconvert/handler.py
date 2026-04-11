"""Lambda handler triggered by S3 upload to raw media bucket.

Submits an AWS MediaConvert job to transcode the uploaded MP4
into AES-128 encrypted HLS output in the encrypted media bucket.
"""

import json
import os
import urllib.parse

import boto3


def get_mediaconvert_client():
    """Return a MediaConvert client using the account-specific endpoint."""
    endpoint = os.environ["MEDIACONVERT_ENDPOINT"]
    return boto3.client("mediaconvert", endpoint_url=endpoint)


def build_job_settings(source_key, input_bucket, output_bucket, role_arn):
    """Build the MediaConvert job settings for HLS with AES-128 encryption.

    Args:
        source_key: S3 object key of the uploaded media file.
        input_bucket: Name of the raw media S3 bucket.
        output_bucket: Name of the encrypted output S3 bucket.
        role_arn: IAM role ARN for MediaConvert to assume.

    Returns:
        Dictionary containing the full MediaConvert job configuration.
    """
    input_s3_url = f"s3://{input_bucket}/{source_key}"
    output_s3_prefix = f"s3://{output_bucket}/{os.path.splitext(source_key)[0]}/"

    return {
        "Role": role_arn,
        "Settings": {
            "Inputs": [
                {
                    "FileInput": input_s3_url,
                    "AudioSelectors": {
                        "Audio Selector 1": {
                            "DefaultSelection": "DEFAULT"
                        }
                    },
                    "VideoSelector": {},
                }
            ],
            "OutputGroups": [
                {
                    "Name": "HLS Group",
                    "OutputGroupSettings": {
                        "Type": "HLS_GROUP_SETTINGS",
                        "HlsGroupSettings": {
                            "Destination": output_s3_prefix,
                            "SegmentLength": 6,
                            "MinSegmentLength": 0,
                            "Encryption": {
                                "EncryptionMethod": "AES128",
                                "Type": "STATIC_KEY",
                                "StaticKeyProvider": {
                                    "StaticKeyValue": os.environ["HLS_AES_KEY"],
                                    "Url": os.environ["HLS_KEY_URI"],
                                },
                            },
                        },
                    },
                    "Outputs": [
                        {
                            "ContainerSettings": {
                                "Container": "M3U8",
                            },
                            "VideoDescription": {
                                "CodecSettings": {
                                    "Codec": "H_264",
                                    "H264Settings": {
                                        "RateControlMode": "QVBR",
                                        "MaxBitrate": 5000000,
                                        "QvbrSettings": {
                                            "QvbrQualityLevel": 7
                                        },
                                    },
                                },
                                "Width": 1920,
                                "Height": 1080,
                            },
                            "AudioDescriptions": [
                                {
                                    "CodecSettings": {
                                        "Codec": "AAC",
                                        "AacSettings": {
                                            "Bitrate": 128000,
                                            "CodingMode": "CODING_MODE_2_0",
                                            "SampleRate": 48000,
                                        },
                                    },
                                    "AudioSourceName": "Audio Selector 1",
                                }
                            ],
                            "NameModifier": "_1080p",
                        }
                    ],
                }
            ],
        },
        "Tags": {
            "Project": "secure-media-platform",
            "Phase": "phase1-ingestion",
            "SourceKey": source_key,
        },
    }


def handler(event, context):
    """Handle S3 event and submit MediaConvert transcoding job.

    Args:
        event: S3 event notification containing bucket and object details.
        context: Lambda execution context.

    Returns:
        Dictionary with job ID and status.
    """
    record = event["Records"][0]
    bucket = record["s3"]["bucket"]["name"]
    key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

    print(f"Processing upload: s3://{bucket}/{key}")

    if not key.lower().endswith((".mp4", ".mov", ".mkv", ".avi")):
        print(f"Skipping non-video file: {key}")
        return {"statusCode": 200, "body": "Skipped non-video file"}

    mediaconvert = get_mediaconvert_client()
    output_bucket = os.environ["OUTPUT_BUCKET"]
    role_arn = os.environ["MEDIACONVERT_ROLE_ARN"]

    job_config = build_job_settings(key, bucket, output_bucket, role_arn)
    response = mediaconvert.create_job(**job_config)

    job_id = response["Job"]["Id"]
    print(f"MediaConvert job submitted: {job_id}")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "job_id": job_id,
            "source": f"s3://{bucket}/{key}",
            "status": "SUBMITTED"
        }),
    }
