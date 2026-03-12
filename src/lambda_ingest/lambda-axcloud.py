import os
import time
import json
from dataclasses import dataclass
from typing import Optional, Dict, Any

import boto3
from botocore.exceptions import ClientError


@dataclass
class AthenaConfig:
    database: str
    output_location: str
    workgroup: str
    region_name: str

    @classmethod
    def from_env(cls) -> "AthenaConfig":
        return cls(
            database=os.getenv("ATHENA_DATABASE", "default"),
            output_location=os.getenv("ATHENA_OUTPUT_LOCATION", ""),
            workgroup=os.getenv("ATHENA_WORKGROUP", "primary"),
            region_name=os.getenv("AWS_REGION", "us-east-1"),
        )

    def validate(self) -> None:
        if not self.output_location:
            raise ValueError("ATHENA_OUTPUT_LOCATION não foi informado.")

        if not self.output_location.startswith("s3://"):
            raise ValueError(
                "ATHENA_OUTPUT_LOCATION inválido. Use o formato s3://bucket/prefixo/"
            )


class AthenaQueryService:
    def __init__(self, config: AthenaConfig):
        self.config = config
        self.config.validate()
        self.client = boto3.client("athena", region_name=self.config.region_name)

    def start_query(self, query: str) -> str:
        response = self.client.start_query_execution(
            QueryString=query,
            QueryExecutionContext={
                "Database": self.config.database
            },
            ResultConfiguration={
                "OutputLocation": self.config.output_location
            },
            WorkGroup=self.config.workgroup
        )
        return response["QueryExecutionId"]

    def get_query_status(self, query_execution_id: str) -> Dict[str, Any]:
        response = self.client.get_query_execution(
            QueryExecutionId=query_execution_id
        )
        return response["QueryExecution"]["Status"]

    def wait_for_completion(
        self,
        query_execution_id: str,
        poll_seconds: int = 2,
        timeout_seconds: int = 60
    ) -> Dict[str, Any]:
        elapsed = 0

        while elapsed < timeout_seconds:
            status = self.get_query_status(query_execution_id)
            state = status["State"]

            if state in ("SUCCEEDED", "FAILED", "CANCELLED"):
                return status

            time.sleep(poll_seconds)
            elapsed += poll_seconds

        raise TimeoutError(
            f"Tempo limite excedido aguardando a query {query_execution_id}."
        )


class LambdaResponseFactory:
    @staticmethod
    def success(body: Dict[str, Any], status_code: int = 200) -> Dict[str, Any]:
        return {
            "statusCode": status_code,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(body, ensure_ascii=False)
        }

    @staticmethod
    def error(message: str, status_code: int = 500) -> Dict[str, Any]:
        return {
            "statusCode": status_code,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": message}, ensure_ascii=False)
        }


def lambda_handler(event: Dict[str, Any], context: Optional[Any]) -> Dict[str, Any]:
    """
    Exemplo de payload esperado:
    {
        "query": "SELECT * FROM meu_database.minha_tabela LIMIT 10",
        "wait_for_completion": true
    }
    """
    try:
        query = event.get("query")
        wait_for_completion = event.get("wait_for_completion", False)

        if not query:
            return LambdaResponseFactory.error(
                "Campo 'query' é obrigatório no evento.",
                400
            )

        config = AthenaConfig.from_env()
        athena_service = AthenaQueryService(config)

        query_execution_id = athena_service.start_query(query)

        response_body = {
            "message": "Query enviada com sucesso.",
            "query_execution_id": query_execution_id,
            "database": config.database,
            "workgroup": config.workgroup,
            "output_location": config.output_location
        }

        if wait_for_completion:
            final_status = athena_service.wait_for_completion(query_execution_id)
            response_body["final_status"] = final_status

        return LambdaResponseFactory.success(response_body)

    except ValueError as exc:
        return LambdaResponseFactory.error(str(exc), 400)

    except TimeoutError as exc:
        return LambdaResponseFactory.error(str(exc), 408)

    except ClientError as exc:
        return LambdaResponseFactory.error(
            f"Erro da AWS ao executar Athena: {str(exc)}",
            500
        )

    except Exception as exc:
        return LambdaResponseFactory.error(
            f"Erro inesperado: {str(exc)}",
            500
        )