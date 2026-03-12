import os
import time

import boto3


def load_sql_from_s3(s3_uri: str) -> str:
    if not s3_uri.startswith("s3://"):
        raise ValueError("SQL_S3_URI deve estar no formato s3://bucket/chave.sql")

    bucket_and_key = s3_uri[len("s3://") :]
    bucket, key = bucket_and_key.split("/", 1)
    s3 = boto3.client("s3")
    response = s3.get_object(Bucket=bucket, Key=key)
    return response["Body"].read().decode("utf-8")


def run_athena_query(query: str, database: str, output_location: str, region: str) -> str:
    athena = boto3.client("athena", region_name=region)
    response = athena.start_query_execution(
        QueryString=query,
        QueryExecutionContext={"Database": database},
        ResultConfiguration={"OutputLocation": output_location},
    )
    return response["QueryExecutionId"]


def wait_for_athena(query_execution_id: str, region: str, sleep_seconds: int = 3) -> str:
    athena = boto3.client("athena", region_name=region)
    while True:
        status = athena.get_query_execution(QueryExecutionId=query_execution_id)[
            "QueryExecution"
        ]["Status"]["State"]
        if status in {"SUCCEEDED", "FAILED", "CANCELLED"}:
            return status
        time.sleep(sleep_seconds)


def main() -> None:
    region = os.getenv("AWS_REGION", "sa-east-1")
    database = os.getenv("ATHENA_DATABASE", "default")
    output_location = os.getenv("ATHENA_OUTPUT_LOCATION", "")
    sql_s3_uri = os.getenv("SQL_S3_URI", "")

    if not output_location:
        raise ValueError("ATHENA_OUTPUT_LOCATION is required")
    if not sql_s3_uri:
        raise ValueError("SQL_S3_URI is required")

    sql = load_sql_from_s3(sql_s3_uri)
    query_execution_id = run_athena_query(sql, database, output_location, region)
    final_status = wait_for_athena(query_execution_id, region)

    if final_status != "SUCCEEDED":
        raise RuntimeError(
            f"Athena query finished with status {final_status}. QueryExecutionId={query_execution_id}"
        )

    print(f"Athena query executed successfully. QueryExecutionId={query_execution_id}")


if __name__ == "__main__":
    main()
