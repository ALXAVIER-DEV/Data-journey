import os
import sys
import time
from typing import Dict, Optional, Tuple

import boto3
from awsglue.utils import getResolvedOptions

RUNNER_VERSION = "2026-03-23.1"


def get_args():
    return getResolvedOptions(
        sys.argv,
        [
            "AWS_REGION",
            "ATHENA_DATABASE",
            "ATHENA_OUTPUT_LOCATION",
            "SQL_S3_URI",
        ],
    )


def load_sql_from_s3(s3_uri):
    if not s3_uri.startswith("s3://"):
        raise ValueError("SQL_S3_URI deve estar no formato s3://bucket/chave.sql")

    bucket_and_key = s3_uri[len("s3://") :]
    if "/" not in bucket_and_key:
        raise ValueError(
            "SQL_S3_URI deve incluir bucket e chave, por exemplo s3://bucket/script.sql"
        )

    bucket, key = bucket_and_key.split("/", 1)
    s3 = boto3.client("s3")
    response = s3.get_object(Bucket=bucket, Key=key)
    return response["Body"].read().decode("utf-8")


def run_athena_query(query, database, output_location, region):
    athena = boto3.client("athena", region_name=region)
    response = athena.start_query_execution(
        QueryString=query,
        QueryExecutionContext={"Database": database},
        ResultConfiguration={"OutputLocation": output_location},
    )
    return response["QueryExecutionId"]


def wait_for_athena(
    query_execution_id, region, sleep_seconds = 3):
    athena = boto3.client("athena", region_name=region)
    while True:
        query_execution = athena.get_query_execution(QueryExecutionId=query_execution_id)[
            "QueryExecution"
        ]
        query_status = query_execution["Status"]
        status = query_status["State"]
        reason = query_status.get("StateChangeReason")
        if status in {"SUCCEEDED", "FAILED", "CANCELLED"}:
            return status, reason
        time.sleep(sleep_seconds)


def main():
    args = get_args()
    region = args["AWS_REGION"]
    database = args["ATHENA_DATABASE"]
    output_location = args["ATHENA_OUTPUT_LOCATION"]
    sql_s3_uri = args["SQL_S3_URI"]

    print(
        f"Glue Athena runner version={RUNNER_VERSION} region={region} "
        f"database={database} sql_s3_uri={sql_s3_uri}"
    )

    sql = load_sql_from_s3(sql_s3_uri)
    query_execution_id = run_athena_query(sql, database, output_location, region)
    print(f"Athena query started. QueryExecutionId={query_execution_id}")
    final_status, failure_reason = wait_for_athena(query_execution_id, region)

    if final_status != "SUCCEEDED":
        error_message = (
            f"Athena query finished with status {final_status}. "
            f"QueryExecutionId={query_execution_id}"
        )
        if failure_reason:
            error_message = f"{error_message}. Reason: {failure_reason}"
        raise RuntimeError(error_message)

    print(f"Athena query executed successfully. QueryExecutionId={query_execution_id}")


if __name__ == "__main__":
    main()


