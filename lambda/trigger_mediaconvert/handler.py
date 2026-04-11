"""Lambda handler triggered by S3 upload to raw media bucket.

Submits an AWS MediaConvert job to transcode the uploaded MP4
into AES-128 encrypted HLS output with adaptive bitrate renditions
in the encrypted media bucket.
"""

import json
import os
import urllib.parse

import boto3

# Adaptive bitrate renditions — each gets its own HLS variant
RENDITIONS = [
    {"name": "1080p", "width": 1920, "height": 1080, "bitrate": 5000000, "quality": 7},
    {"name": "720p", "width": 1280, "height": 720, "bitrate": 3000000, "quality": 7},
    {"name": "480p", "width": 854, "height": 480, "bitrate": 1500000, "quality": 7},
]


def get_mediaconvert_client():
    """Return a MediaConvert client using the account-specific endpoint."""
    endpoint = os.environ["MEDIACONVERT_ENDPOINT"]
    return boto3.client("mediaconvert", endpoint_url=endpoint)


def build_rendition_output(rendition):
    """Build a single HLS output for a given rendition.

    Args:
        rendition: Dict with name, width, height, bitrate, and quality.

    Returns:
        Dictionary representing one MediaConvert output.
    """
    return {
        "ContainerSettings": {
            "Container": "M3U8",
        },
        "VideoDescription": {
            "CodecSettings": {
                "Codec": "H_264",
                "H264Settings": {
                    "RateControlMode": "QVBR",
                    "MaxBitrate": rendition["bitrate"],
                    "QvbrSettings": {
                        "QvbrQualityLevel": rendition["quality"],
                    },
                },
            },
            "Width": rendition["width"],
            "Height": rendition["height"],
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
        "NameModifier": f"_{rendition['name']}",
    }


def build_job_settings(source_key, input_bucket, output_bucket, role_arn):
    """Build MediaConvert job settings for adaptive bitrate HLS with AES-128.

    Args:
        source_key: S3 object key of the uploaded media file.
        input_bucket: Name of the raw media S3 bucket.
        output_bucket: Name of the encrypted output S3 bucket.
        role_arn: IAM role ARN for MediaConvert to assume.

    Returns:
        Dictionary containing the full MediaConvert job configuration.
    """
    input_s3_url = f"s3://{input_bucket}/{source_key}"
    content_name = os.path.splitext(source_key)[0]
    output_s3_prefix = f"s3://{output_bucket}/{content_name}/"

    outputs = [build_rendition_output(r) for r in RENDITIONS]

    queue_arn = os.environ.get("MEDIACONVERT_QUEUE", "")

    job = {
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
                    "Name": "HLS Adaptive Bitrate",
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
                    "Outputs": outputs,
                }
            ],
        },
        "Tags": {
            "Project": "secure-media-platform",
            "Phase": "phase1-ingestion",
            "SourceKey": source_key,
        },
    }

    if queue_arn:
        job["Queue"] = queue_arn

    return job


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
    print(f"MediaConvert job submitted: {job_id} with {len(RENDITIONS)} renditions")

    return {
        "statusCode": 200,
        "body": json.dumps({
            "job_id": job_id,
            "source": f"s3://{bucket}/{key}",
            "renditions": [r["name"] for r in RENDITIONS],
            "status": "SUBMITTED",
        }),
    }
