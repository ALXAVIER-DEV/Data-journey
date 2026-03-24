import json
import os
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, List, Tuple

import boto3


@dataclass
class IngestConfig:
    bucket_name: str
    bronze_prefix: str
    environment: str

    @classmethod
    def from_env(cls) -> "IngestConfig":
        return cls(
            bucket_name=os.environ["S3_BUCKET"],
            bronze_prefix=os.getenv("BRONZE_PREFIX", "bronze"),
            environment=os.getenv("ENVIRONMENT", "dev"),
        )

    def build_object_key(self, message_id: str, ingested_at: datetime) -> str:
        date_partition = ingested_at.strftime("%Y%m%d")
        return (
            f"{self.bronze_prefix}/raw/date={date_partition}/"
            f"message_id={message_id}.json"
        )


class S3DataLakeWriter:
    def __init__(self, bucket_name: str):
        self.bucket_name = bucket_name
        self.client = boto3.client("s3")

    def write_json(self, key: str, payload: Dict[str, Any]) -> None:
        self.client.put_object(
            Bucket=self.bucket_name,
            Key=key,
            Body=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            ContentType="application/json",
        )


def _parse_json_if_possible(value: Any) -> Any:
    if not isinstance(value, str):
        return value

    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return value


def _normalize_sqs_record(
    record: Dict[str, Any], config: IngestConfig
) -> Tuple[str, Dict[str, Any]]:
    ingested_at = datetime.now(timezone.utc)
    envelope = _parse_json_if_possible(record.get("body", ""))

    if isinstance(envelope, dict) and envelope.get("Type") == "Notification":
        raw_message = envelope.get("Message")
        message_id = (
            envelope.get("MessageId") or record.get("messageId") or str(uuid.uuid4())
        )
        source_metadata = {
            "source_type": "sns",
            "topic_arn": envelope.get("TopicArn"),
            "subject": envelope.get("Subject"),
            "published_at": envelope.get("Timestamp"),
        }
    else:
        raw_message = envelope
        message_id = record.get("messageId") or str(uuid.uuid4())
        source_metadata = {
            "source_type": "sqs",
            "attributes": record.get("attributes", {}),
        }

    normalized_payload = {
        "message_id": message_id,
        "environment": config.environment,
        "ingested_at": ingested_at.isoformat(),
        "payload": _parse_json_if_possible(raw_message),
        "source": source_metadata,
    }
    object_key = config.build_object_key(message_id, ingested_at)
    return object_key, normalized_payload


def _build_direct_invoke_payload(
    event: Dict[str, Any], config: IngestConfig
) -> Tuple[str, Dict[str, Any]]:
    ingested_at = datetime.now(timezone.utc)
    message_id = str(uuid.uuid4())
    normalized_payload = {
        "message_id": message_id,
        "environment": config.environment,
        "ingested_at": ingested_at.isoformat(),
        "payload": event,
        "source": {
            "source_type": "direct-invoke",
        },
    }
    object_key = config.build_object_key(message_id, ingested_at)
    return object_key, normalized_payload


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    config = IngestConfig.from_env()
    writer = S3DataLakeWriter(config.bucket_name)

    records: List[Dict[str, Any]] = event.get("Records", [])
    if not records:
        object_key, payload = _build_direct_invoke_payload(event, config)
        writer.write_json(object_key, payload)
        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": "Evento gravado com sucesso no data lake.",
                    "bucket": config.bucket_name,
                    "key": object_key,
                },
                ensure_ascii=False,
            ),
        }

    batch_item_failures = []
    processed_keys = []

    for record in records:
        try:
            object_key, payload = _normalize_sqs_record(record, config)
            writer.write_json(object_key, payload)
            processed_keys.append(object_key)
        except Exception:
            batch_item_failures.append(
                {"itemIdentifier": record.get("messageId", str(uuid.uuid4()))}
            )

    return {
        "batchItemFailures": batch_item_failures,
        "processedCount": len(processed_keys),
        "processedKeys": processed_keys,
    }
