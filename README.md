# Data-journey

Laboratorio de ingestao de dados serverless na AWS com Terraform, GitHub Actions, Lambda, SNS, SQS, S3, Athena e Glue Python Shell.

## Visao Geral

O projeto implementa um fluxo orientado a eventos para receber mensagens, persisti-las no data lake e preparar uma camada analitica para consultas no Athena.

Fluxo atual:

```text
Producer
  |
  v
SNS Topic
  |
  v
SQS Queue
  |
  v
Lambda ingest
  |
  v
S3 bronze/raw/date=YYYYMMDD/
  |
  v
Glue Python Shell
  |
  v
Athena SQL
  |
  v
Curated layer
```

## O Que Ja Funciona

- Provisionamento principal com Terraform.
- Deploy por ambiente com GitHub Actions e OIDC.
- Fluxo `SNS -> SQS -> Lambda -> S3 bronze/raw` validado em `dev`.
- Upload automatizado do ZIP da Lambda, SQL do Athena e script do Glue para S3.
- Glue Python Shell executando SQL no Athena a partir de arquivo no S3.

## O Que Ainda Esta Em Evolucao

- Stabilizacao do SQL Athena para a camada curated.
- Definicao final da modelagem Iceberg da tabela `curated_messages`.
- Validacoes automatizadas mais fortes para SQL, Lambda e Glue.
- Documentacao operacional de troubleshooting e rerun.

## Servicos AWS Utilizados

| Servico | Papel |
| --- | --- |
| Amazon SNS | Publicacao de eventos |
| Amazon SQS | Buffer e desacoplamento |
| AWS Lambda | Ingestao e gravacao no data lake |
| Amazon S3 | Armazenamento das camadas de dados e artefatos |
| AWS Glue Python Shell | Orquestracao de SQL no Athena |
| Amazon Athena | DDL, DML e consultas analiticas |
| Amazon CloudWatch | Logs de Lambda e Glue |
| IAM | Controle de acesso |
| GitHub Actions | CI/CD |
| Terraform | Provisionamento de infraestrutura |

## Estrutura do Repositorio

```text
.
|-- .github/workflows/
|   |-- deploy-dev.yml
|   |-- deploy-hom.yml
|   |-- deploy-prod.yml
|   `-- terraform.yml
|-- athena/
|   |-- ddl/
|   |   |-- create_parquet_table.sql
|   |   `-- create_raw_table.sql
|   `-- dml/
|       `-- insert_curated_messages.sql
|-- docs/
|   |-- execution-plan.md
|   `-- project-assessment.md
|-- glue/python_shell/
|   `-- runner.py
|-- infra/
|   |-- iam/
|   `-- terraform/
|-- scripts/
|   |-- github/
|   |-- validate-athena-sql.sh
|   `-- validate-glue-runner.sh
`-- src/
    |-- app/
    `-- lambda_ingest/
        |-- lambda-axcloud.py
        `-- main.py
```

## Componentes Principais

### Lambda de ingestao

Arquivo principal:

- [main.py](e:/Projetos/Data-journey/src/lambda_ingest/main.py)

Responsabilidades:

- consumir mensagens da SQS
- interpretar envelope SNS
- normalizar payload
- gravar JSON no S3 em `bronze/raw/date=YYYYMMDD/`

Exemplo de chave gravada:

```text
bronze/raw/date=20260324/message_id=9801c68a-c82b-5f15-994a-a4b626a47555.json
```

### Glue runner

Arquivo principal:

- [runner.py](e:/Projetos/Data-journey/glue/python_shell/runner.py)

Responsabilidades:

- ler SQL do S3
- dividir multiplos statements
- executar cada statement no Athena
- aguardar conclusao e propagar erro quando houver falha

### SQL Athena

Arquivos principais:

- [create_raw_table.sql](e:/Projetos/Data-journey/athena/ddl/create_raw_table.sql)
- [create_parquet_table.sql](e:/Projetos/Data-journey/athena/ddl/create_parquet_table.sql)
- [insert_curated_messages.sql](e:/Projetos/Data-journey/athena/dml/insert_curated_messages.sql)

Observacao:

- a camada curated esta em migracao para Iceberg
- a sintaxe SQL ainda esta sendo ajustada para o parser do Athena em runtime

## Ambientes

O projeto trabalha com tres ambientes:

- `dev`
- `hom`
- `prod`

Os nomes dos principais recursos seguem o padrao:

```text
<environment>-axcloud-lab-<recurso>
```

Exemplos em `dev`:

- bucket: `dev-axcloud-lab-sa-east-1-data`
- lambda: `dev-axcloud-lab-lambda-ingest`
- glue job: `dev-axcloud-lab-glue-shell-athena-exec`
- sns topic: `dev-axcloud-lab-topic-ingest`
- sqs queue: `dev-axcloud-lab-queue-ingest`

## Deploy

### Fluxo de deploy

1. O workflow empacota a Lambda.
2. O workflow envia Lambda ZIP, SQL e Glue runner para S3.
3. O workflow reutilizavel do Terraform aplica a infraestrutura.
4. O job de deploy atualiza o codigo da Lambda e o `ScriptLocation` do Glue.
5. Um smoke test publica uma mensagem no SNS.

### Workflows

- [deploy-dev.yml](e:/Projetos/Data-journey/.github/workflows/deploy-dev.yml)
- [deploy-hom.yml](e:/Projetos/Data-journey/.github/workflows/deploy-hom.yml)
- [deploy-prod.yml](e:/Projetos/Data-journey/.github/workflows/deploy-prod.yml)
- [terraform.yml](e:/Projetos/Data-journey/.github/workflows/terraform.yml)

## Validacao Manual

### Publicar mensagem no SNS

```bash
aws sns publish \
  --topic-arn arn:aws:sns:sa-east-1:584047610071:dev-axcloud-lab-topic-ingest \
  --message "{\"hello\":\"world\",\"from\":\"manual-test\"}" \
  --region sa-east-1
```

### Verificar arquivo na camada bronze

```bash
aws s3 ls s3://dev-axcloud-lab-sa-east-1-data/bronze/raw/ --recursive --region sa-east-1
```

### Verificar configuracao do Glue job

```bash
aws glue get-job \
  --job-name dev-axcloud-lab-glue-shell-athena-exec \
  --region sa-east-1 \
  --query 'Job.DefaultArguments' \
  --output json
```

## Principais Oportunidades

### 1. Fechar a camada curated com estabilidade

- consolidar a sintaxe SQL compativel com Athena
- definir estrategia final de tabela Iceberg
- documentar processo de recriacao da tabela quando houver mudanca de formato

### 2. Adicionar quality gates reais

- testes unitarios da Lambda
- validacao mais forte do SQL
- checagem automatica do Glue runner
- smoke test de ponta a ponta apos deploy

### 3. Melhorar observabilidade

- logs estruturados na Lambda
- trilha clara de erro para Glue e Athena
- runbook para erros recorrentes de bucket, parser SQL e IAM

### 4. Reduzir codigo e arquivos legados

- decidir o papel de `src/app/`
- decidir se `lambda-axcloud.py` ainda deve existir
- remover artefatos e caminhos que ja nao fazem parte do fluxo principal

### 5. Tornar a documentacao operacional

- passo a passo de bootstrap por ambiente
- comandos de diagnostico AWS CLI
- estrategia de rollback

## Troubleshooting Rapido

### Glue: `Unable to verify/create output bucket`

Validar:

- `--ATHENA_OUTPUT_LOCATION`
- permissao `s3:GetBucketLocation` na role do Glue
- policy/KMS do bucket de resultados

### Athena: erro de parser SQL

Validar:

- dialeto atual do Athena
- compatibilidade entre Hive-style DDL e sintaxe `WITH (...)`
- quoting de campos como `"from"`

### Deploy: warning de Node 20

Os workflows ja foram ajustados com:

- `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true`

## Documentos de Apoio

- [project-assessment.md](e:/Projetos/Data-journey/docs/project-assessment.md)
- [execution-plan.md](e:/Projetos/Data-journey/docs/execution-plan.md)

## Status Atual

O projeto esta em um ponto bom de infraestrutura e ingestao raw. O principal foco agora e estabilizar a camada Athena/Glue/curated para que o laboratorio fique demonstravel ponta a ponta com menos intervencao manual.
