#!/usr/bin/env bash

set -euo pipefail

SQL_FILE="${1:-athena/dml/insert_curated_messages.sql}"

if [[ ! -f "$SQL_FILE" ]]; then
  echo "::error::Arquivo SQL nao encontrado: $SQL_FILE"
  exit 1
fi

if grep -Eq '^\s*data\s+"aws_|^\s*resource\s+"aws_|^\s*module\s+"|^\s*provider\s+"|^\s*variable\s+"' "$SQL_FILE"; then
  echo "::error::Arquivo SQL contem sintaxe de Terraform: $SQL_FILE"
  exit 1
fi

if ! grep -Eiq '\b(select|insert|create|with|update|delete|merge|alter|drop)\b' "$SQL_FILE"; then
  echo "::error::Arquivo SQL nao parece conter um comando SQL valido: $SQL_FILE"
  exit 1
fi

echo "SQL validado: $SQL_FILE"
