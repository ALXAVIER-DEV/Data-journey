resource "aws_s3_bucket" "data_bucket" {
  count  = var.create_data_bucket ? 1 : 0
  bucket = var.bucket_name
  lifecycle {
  prevent_destroy = true
  ignore_changes  = [bucket]  
  }
  
  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
  
}
Analisando o workflow, o problema central é que o **deploy da Lambda está em outro workflow** que não tem dependência do Terraform. Preciso ver o workflow principal, mas posso identificar e corrigir todos os problemas no `terraform.yml` agora.

---

### Problemas identificados

**1. Terraform Apply sem output de recursos criados** — não há como o workflow chamador saber se a Lambda foi criada, impossibilitando dependência condicional.

**2. Sem `output` de recursos provisionados** — o workflow não expõe via `outputs` se recursos como Lambda, Glue, SNS foram criados com sucesso.

**3. Import hardcoded** — o nome do bucket de dados está hardcoded (`axcloud-lab-`) em vez de vir de um input ou tfvars.

**4. `workspace select` repetido 4 vezes** — é redundante e pode causar race condition se o workspace mudar entre steps.

**5. Sem verificação pós-apply** — não confirma que os recursos críticos (Lambda, etc.) existem após o apply.

---

```yaml
name: "Terraform Workflow"
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      aws-assume-role-arn:
        type: string
        required: true
      aws-region:
        type: string
        required: true
      aws-statefile-bucket:
        type: string
        required: true
      aws-lock-athena-table:
        type: string
        required: true
      # ✅ FIX 3: Input explícito para o bucket de dados
      data-bucket-name:
        type: string
        required: false
        default: ""

    # ✅ FIX 1 e 2: Outputs para workflows dependentes saberem o que foi criado
    outputs:
      lambda-function-name:
        description: "Nome da função Lambda provisionada"
        value: ${{ jobs.terraform.outputs.lambda-function-name }}
      apply-status:
        description: "Status do terraform apply"
        value: ${{ jobs.terraform.outputs.apply-status }}

jobs:
  terraform:
    runs-on: ubuntu-latest
    concurrency:
      group: terraform-${{ inputs.environment }}
      cancel-in-progress: false
    defaults:
      run:
        shell: bash

    # ✅ FIX 1 e 2: Mapeamento de outputs do job
    outputs:
      lambda-function-name: ${{ steps.tf-output.outputs.lambda-function-name }}
      apply-status: ${{ steps.terraform-apply.outputs.apply-status }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.8.3
          terraform_wrapper: false  # ✅ Necessário para capturar outputs do terraform

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ inputs.aws-assume-role-arn }}
          role-session-name: GitHub_to_AWS_via_FederatedOIDC
          aws-region: ${{ inputs.aws-region }}

      - name: Ensure Terraform backend exists
        run: |
          set -euo pipefail

          BUCKET="${{ inputs.aws-statefile-bucket }}"
          REGION="${{ inputs.aws-region }}"
          LOCK_TABLE="${{ inputs.aws-lock-athena-table }}"
          DDB_LOCK_ENABLED="false"

          if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
            if [ "$REGION" = "us-east-1" ]; then
              aws s3api create-bucket --bucket "$BUCKET"
            else
              aws s3api create-bucket \
                --bucket "$BUCKET" \
                --create-bucket-configuration LocationConstraint="$REGION"
            fi
            aws s3api wait bucket-exists --bucket "$BUCKET"
          fi

          if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$REGION" >/dev/null 2>&1; then
            DDB_LOCK_ENABLED="true"
          else
            DDB_ERR="$(aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$REGION" 2>&1 || true)"
            if echo "$DDB_ERR" | grep -q "ResourceNotFoundException"; then
              CREATE_ERR_FILE="$(mktemp)"
              if aws dynamodb create-table \
                --table-name "$LOCK_TABLE" \
                --attribute-definitions AttributeName=LockID,AttributeType=S \
                --key-schema AttributeName=LockID,KeyType=HASH \
                --billing-mode PAY_PER_REQUEST \
                --region "$REGION" >/dev/null 2>"$CREATE_ERR_FILE"; then
                aws dynamodb wait table-exists --table-name "$LOCK_TABLE" --region "$REGION"
                DDB_LOCK_ENABLED="true"
              else
                CREATE_ERR="$(cat "$CREATE_ERR_FILE")"
                if echo "$CREATE_ERR" | grep -q "AccessDeniedException"; then
                  echo "Warning: sem permissão para criar tabela DynamoDB. Continuando sem state locking."
                  DDB_LOCK_ENABLED="false"
                else
                  echo "$CREATE_ERR"
                  exit 1
                fi
              fi
              rm -f "$CREATE_ERR_FILE"
            elif echo "$DDB_ERR" | grep -q "AccessDeniedException"; then
              echo "Warning: sem permissão para descrever tabela DynamoDB. Continuando sem state locking."
              DDB_LOCK_ENABLED="false"
            else
              echo "$DDB_ERR"
              exit 1
            fi
          fi

          echo "TF_DDB_LOCK_ENABLED=$DDB_LOCK_ENABLED" >> "$GITHUB_ENV"
          echo "TF_DDB_LOCK_TABLE=$LOCK_TABLE"         >> "$GITHUB_ENV"

      - name: Terraform Initialize
        run: |
          cd infra/terraform
          if [ "${TF_DDB_LOCK_ENABLED}" = "true" ]; then
            terraform init -input=false \
              -backend-config="bucket=${{ inputs.aws-statefile-bucket }}" \
              -backend-config="key=${{ github.repository }}/${{ inputs.environment }}/terraform.tfstate" \
              -backend-config="region=${{ inputs.aws-region }}" \
              -backend-config="dynamodb_table=${TF_DDB_LOCK_TABLE}" \
              -backend-config="encrypt=true"
          else
            terraform init -input=false \
              -backend-config="bucket=${{ inputs.aws-statefile-bucket }}" \
              -backend-config="key=${{ github.repository }}/${{ inputs.environment }}/terraform.tfstate" \
              -backend-config="region=${{ inputs.aws-region }}" \
              -backend-config="encrypt=true"
          fi

      - name: Terraform Validate
        run: |
          cd infra/terraform
          terraform validate

      # ✅ FIX 4: Workspace selecionado uma única vez e salvo no GITHUB_ENV
      - name: Select Terraform Workspace
        run: |
          cd infra/terraform
          terraform workspace select -or-create=true ${{ inputs.environment }}
          echo "TF_WORKSPACE=${{ inputs.environment }}" >> "$GITHUB_ENV"

      # ✅ FIX 3: Import usando input explícito com fallback para convenção de nome
      - name: Import existing resources
        run: |
          cd infra/terraform

          DATA_BUCKET="${{ inputs.data-bucket-name }}"
          if [ -z "$DATA_BUCKET" ]; then
            DATA_BUCKET="axcloud-lab-${{ inputs.aws-region }}-data"
            echo "data-bucket-name não fornecido. Usando convenção: $DATA_BUCKET"
          fi

          if ! terraform state show 'aws_s3_bucket.data_bucket[0]' > /dev/null 2>&1; then
            if aws s3api head-bucket --bucket "$DATA_BUCKET" 2>/dev/null; then
              echo "Importando bucket existente: $DATA_BUCKET"
              terraform import 'aws_s3_bucket.data_bucket[0]' "$DATA_BUCKET"
            else
              echo "Bucket $DATA_BUCKET não existe na AWS. Será criado pelo Terraform."
            fi
          else
            echo "aws_s3_bucket.data_bucket[0] já está no state. Pulando import."
          fi

      - name: Force unlock stale state lock
        if: env.TF_DDB_LOCK_ENABLED == 'true'
        run: |
          cd infra/terraform

          LOCK_KEY="${{ inputs.aws-statefile-bucket }}/env:/${{ inputs.environment }}/${{ github.repository }}/${{ inputs.environment }}/terraform.tfstate"

          LOCK_ITEM=$(aws dynamodb get-item \
            --table-name "${{ inputs.aws-lock-athena-table }}" \
            --region "${{ inputs.aws-region }}" \
            --key "{\"LockID\": {\"S\": \"$LOCK_KEY\"}}" \
            --query 'Item' \
            --output json 2>/dev/null || echo "null")

          if [ "$LOCK_ITEM" != "null" ] && [ -n "$LOCK_ITEM" ]; then
            LOCK_ID=$(echo "$LOCK_ITEM" | jq -r '.Info.S // empty' | jq -r '.ID // empty' 2>/dev/null || echo "")
            CREATED=$(echo "$LOCK_ITEM" | jq -r '.Info.S // empty' | jq -r '.Created // empty' 2>/dev/null || echo "desconhecido")
            echo "⚠️ Lock fantasma detectado. Criado em: $CREATED"

            if [ -n "$LOCK_ID" ]; then
              terraform force-unlock -force "$LOCK_ID"
              echo "✅ Lock removido via terraform force-unlock: $LOCK_ID"
            else
              aws dynamodb delete-item \
                --table-name "${{ inputs.aws-lock-athena-table }}" \
                --region "${{ inputs.aws-region }}" \
                --key "{\"LockID\": {\"S\": \"$LOCK_KEY\"}}"
              echo "✅ Lock removido diretamente no DynamoDB."
            fi
          else
            echo "✅ Nenhum lock ativo encontrado. Prosseguindo."
          fi

      - name: Terraform Plan
        id: terraform-plan
        run: |
          cd infra/terraform
          terraform plan \
            -input=false \
            -var-file="./modules/envs/${{ inputs.environment }}/terraform.tfvars" \
            -out="${{ inputs.environment }}.plan"

      - name: Terraform Apply
        id: terraform-apply
        run: |
          cd infra/terraform
          terraform apply -auto-approve -input=false "${{ inputs.environment }}.plan"
          echo "apply-status=success" >> "$GITHUB_OUTPUT"

      # ✅ FIX 2 e 5: Captura outputs do Terraform e verifica recursos críticos
      - name: Capture Terraform outputs
        id: tf-output
        run: |
          cd infra/terraform

          # Captura o nome da Lambda do output do Terraform (ajuste o nome do output conforme seu main.tf)
          LAMBDA_NAME=$(terraform output -raw lambda_function_name 2>/dev/null || echo "")

          if [ -n "$LAMBDA_NAME" ]; then
            echo "lambda-function-name=$LAMBDA_NAME" >> "$GITHUB_OUTPUT"
            echo "✅ Lambda provisionada: $LAMBDA_NAME"
          else
            echo "⚠️ Output 'lambda_function_name' não encontrado no Terraform. Verifique seu main.tf."
            echo "lambda-function-name=" >> "$GITHUB_OUTPUT"
          fi

      # ✅ FIX 5: Verificação pós-apply dos recursos críticos
      - name: Verify critical resources
        run: |
          cd infra/terraform
          REGION="${{ inputs.aws-region }}"
          FAILED=0

          LAMBDA_NAME=$(terraform output -raw lambda_function_name 2>/dev/null || echo "")
          if [ -n "$LAMBDA_NAME" ]; then
            if aws lambda get-function --function-name "$LAMBDA_NAME" --region "$REGION" > /dev/null 2>&1; then
              echo "✅ Lambda verificada: $LAMBDA_NAME"
            else
              echo "::error::Lambda '$LAMBDA_NAME' não encontrada após apply!"
              FAILED=1
            fi
          fi

          S3_BUCKET=$(terraform output -raw data_bucket_name 2>/dev/null || echo "")
          if [ -n "$S3_BUCKET" ]; then
            if aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
              echo "✅ Bucket S3 verificado: $S3_BUCKET"
            else
              echo "::error::Bucket S3 '$S3_BUCKET' não encontrado após apply!"
              FAILED=1
            fi
          fi

          if [ "$FAILED" = "1" ]; then
            echo "::error::Um ou mais recursos críticos não foram provisionados corretamente."
            exit 1
          fi

      - name: Notify on failure
        if: failure()
        run: |
          echo "::error::Terraform falhou no ambiente ${{ inputs.environment }}"
          echo "::error::Verifique os logs acima para detalhes do erro"




output "lambda_function_name" {
  value = aws_lambda_function.ingest.function_name
}
output "data_bucket_name" {
  value = aws_s3_bucket.data_bucket[0].id
}