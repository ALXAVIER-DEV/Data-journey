#!/usr/bin/env bash

set -euo pipefail

RUNNER_FILE="${1:-glue/python_shell/runner.py}"

if [[ ! -f "$RUNNER_FILE" ]]; then
  echo "::error::Arquivo do Glue runner nao encontrado: $RUNNER_FILE"
  exit 1
fi

if grep -Eq 'sys\.exit\(|raise SystemExit\(' "$RUNNER_FILE"; then
  echo "::error::Glue runner contem encerramento compativel com SystemExit: $RUNNER_FILE"
  exit 1
fi

if ! grep -Eq '^if __name__ == "__main__":$' "$RUNNER_FILE"; then
  echo "::error::Glue runner nao possui entrypoint esperado: $RUNNER_FILE"
  exit 1
fi

if ! grep -Eq '^    main\(\)$' "$RUNNER_FILE"; then
  echo "::error::Glue runner deve chamar main() diretamente no entrypoint: $RUNNER_FILE"
  exit 1
fi

echo "Glue runner validado: $RUNNER_FILE"
