import os
import sys
import time

import boto3
from botocore.exceptions import ClientError
from awsglue.utils import getResolvedOptions

RUNNER_VERSION = "2026-03-25.2"
CURATED_STAGE_PREFIX = "tmp/curated-messages-stage/"


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


def render_sql_template(sql_text, replacements):
    rendered = sql_text
    for key, value in replacements.items():
        rendered = rendered.replace(f"{{{{{key}}}}}", value)
    return rendered


def split_sql_statements(sql_text):
    statements = []
    current = []
    for line in sql_text.splitlines():
        stripped = line.strip()
        if stripped.startswith("--"):
            continue
        current.append(line)
        if stripped.endswith(";"):
            statement = "\n".join(current).strip()
            if statement:
                statements.append(statement[:-1].strip())
            current = []

    trailing = "\n".join(current).strip()
    if trailing:
        statements.append(trailing)

    return [statement for statement in statements if statement]


def split_s3_uri(s3_uri):
    if not s3_uri.startswith("s3://"):
        raise ValueError(f"URI S3 invalida: {s3_uri}")

    bucket_and_key = s3_uri[len("s3://") :]
    if "/" not in bucket_and_key:
        return bucket_and_key, ""

    bucket, key = bucket_and_key.split("/", 1)
    return bucket, key


def clear_s3_prefix(s3_uri):
    bucket, prefix = split_s3_uri(s3_uri)
    s3 = boto3.client("s3")
    paginator = s3.get_paginator("list_objects_v2")

    deleted = 0
    for page in paginator.paginate(Bucket=bucket, Prefix=prefix):
        contents = page.get("Contents", [])
        if not contents:
            continue

        objects = [{"Key": item["Key"]} for item in contents]
        s3.delete_objects(Bucket=bucket, Delete={"Objects": objects})
        deleted += len(objects)

    print(f"Cleared S3 prefix: {s3_uri} objects_deleted={deleted}")


def run_athena_query(query, database, output_location, region):
    athena = boto3.client("athena", region_name=region)
    response = athena.start_query_execution(
        QueryString=query,
        QueryExecutionContext={"Database": database},
        ResultConfiguration={"OutputLocation": output_location},
    )
    return response["QueryExecutionId"]


def wait_for_athena(query_execution_id, region, sleep_seconds=3):
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
    data_bucket, _ = split_s3_uri(output_location)
    curated_stage_s3_uri = f"s3://{data_bucket}/{CURATED_STAGE_PREFIX}"

    print(
        "Resolved Glue arguments: "
        f"AWS_REGION={region} "
        f"ATHENA_DATABASE={database} "
        f"ATHENA_OUTPUT_LOCATION={output_location} "
        f"SQL_S3_URI={sql_s3_uri}"
    )

    print(
        f"Glue Athena runner version={RUNNER_VERSION} region={region} "
        f"database={database} sql_s3_uri={sql_s3_uri}"
    )

    sql = load_sql_from_s3(sql_s3_uri)
    sql = render_sql_template(sql, {"DATA_BUCKET": data_bucket})
    statements = split_sql_statements(sql)
    if not statements:
        raise ValueError("Nenhum statement SQL valido foi encontrado no arquivo.")

    for index, statement in enumerate(statements, start=1):
        preview = statement.splitlines()[0][:120]
        print(f"Executing statement {index}/{len(statements)}: {preview}")
        if preview == "CREATE TABLE default.curated_messages_stage":
            clear_s3_prefix(curated_stage_s3_uri)
        print(
            f"StartQueryExecution payload: database={database} "
            f"output_location={output_location} "
            f"statement_index={index}"
        )
        try:
            query_execution_id = run_athena_query(statement, database, output_location, region)
        except ClientError as exc:
            error_message = exc.response.get("Error", {}).get("Message", str(exc))
            raise RuntimeError(
                f"StartQueryExecution failed. StatementIndex={index}. "
                f"Preview={preview}. Reason: {error_message}"
            ) from exc
        print(f"Athena query started. QueryExecutionId={query_execution_id}")
        final_status, failure_reason = wait_for_athena(query_execution_id, region)

        if final_status != "SUCCEEDED":
            error_message = (
                f"Athena query finished with status {final_status}. "
                f"QueryExecutionId={query_execution_id}. StatementIndex={index}"
            )
            if failure_reason:
                error_message = f"{error_message}. Reason: {failure_reason}"
            raise RuntimeError(error_message)

    print(f"All Athena statements executed successfully. Statements={len(statements)}")


if __name__ == "__main__":
    main()
