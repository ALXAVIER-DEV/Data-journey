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
- Camada raw modelada em Hive external table sobre JSON particionado por `date`.
- Camada curated gravando em Parquet com carga incremental via tabela de staging.
- Runner do Glue com logs mais claros de `StatementIndex` e limpeza automatica do prefixo temporario da staging.

## O Que Ainda Esta Em Evolucao

- Evolucao da camada curated para um desenho mais robusto de merge/upsert.
- Definicao final se a tabela `curated_messages` permanecera Hive/Parquet ou migrara para Iceberg.
- Validacoes automatizadas mais fortes para SQL, Lambda e Glue.
- Menor dependencia de `MSCK REPAIR TABLE` e de operacoes DDL durante o processamento.

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
- limpar automaticamente o prefixo `tmp/curated-messages-stage/` antes do `CTAS` da staging
- expor no erro o `StatementIndex` e o preview do statement que falhou

### SQL Athena

Arquivos principais:

- [create_raw_table.sql](e:/Projetos/Data-journey/athena/ddl/create_raw_table.sql)
- [create_parquet_table.sql](e:/Projetos/Data-journey/athena/ddl/create_parquet_table.sql)
- [insert_curated_messages.sql](e:/Projetos/Data-journey/athena/dml/insert_curated_messages.sql)

Observacao:

- `create_raw_table.sql` e o primeiro bloco de `insert_curated_messages.sql` usam DDL Hive para tabela externa JSON
- `insert_curated_messages.sql` cria a tabela final `curated_messages` como Hive external table em Parquet
- a carga incremental ocorre em 3 passos: `DROP staging`, `CTAS staging`, `INSERT INTO curated_messages`
- o `CTAS` usa um prefixo fixo em `s3://<bucket>/tmp/curated-messages-stage/`, hoje limpo automaticamente pelo runner
- timestamps ISO8601 sao convertidos para `timestamp` sem timezone antes da gravacao em Parquet
- os arquivos SQL usam o placeholder `{{DATA_BUCKET}}`, resolvido pelo runner com base no bucket do proprio ambiente

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

### Ordem recomendada de validacao

1. publicar uma mensagem de teste no SNS
2. confirmar o arquivo na camada bronze
3. conferir os argumentos do Glue Job
4. validar a role/policies do Glue e acesso ao bucket de output do Athena
5. publicar o SQL e o runner atualizados no S3
6. executar o Glue Job
7. consultar a tabela `default.curated_messages`

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

### Validar role, policies e bucket do Athena

Arquivo:

- [validate-glue-athena-access.ps1](e:/Projetos/Data-journey/scripts/validate-glue-athena-access.ps1)

Uso:

```powershell
.\scripts\validate-glue-athena-access.ps1
.\scripts\validate-glue-athena-access.ps1 -RunS3WriteTest
```

O script verifica:

- Glue Job e role associada
- bucket de output do Athena e regiao
- permissoes minimas de S3, Athena e Glue
- teste opcional real de `PutObject/DeleteObject` no bucket de resultados

### Publicar SQL e runner no S3

Exemplo para `dev`:

```powershell
aws s3 cp `
  .\athena\dml\insert_curated_messages.sql `
  s3://dev-axcloud-lab-sa-east-1-data/sql/dml/insert_curated_messages.sql `
  --region sa-east-1

aws s3 cp `
  .\glue\python_shell\runner.py `
  s3://dev-axcloud-lab-sa-east-1-data/glue/python_shell/runner.py `
  --region sa-east-1
```

Para `hom` e `prod`, publicar no bucket do proprio ambiente mantendo a mesma chave.

### Executar o Glue Job manualmente

```powershell
aws glue start-job-run `
  --job-name dev-axcloud-lab-glue-shell-athena-exec `
  --region sa-east-1
```

Mesmo padrao por ambiente:

- `hom-axcloud-lab-glue-shell-athena-exec`
- `prod-axcloud-lab-glue-shell-athena-exec`

### Consultar a camada curated

```sql
SELECT *
FROM default.curated_messages
ORDER BY processed_at DESC
LIMIT 20;
```

## Como O Processo Funciona Hoje

1. A Lambda grava os eventos brutos em `bronze/raw/date=YYYYMMDD/`.
2. O Glue Job carrega do S3 o arquivo [insert_curated_messages.sql](e:/Projetos/Data-journey/athena/dml/insert_curated_messages.sql).
3. O runner divide o arquivo em statements e executa um por vez no Athena.
4. O SQL garante a tabela raw externa e roda `MSCK REPAIR TABLE`.
5. O SQL garante a tabela `curated_messages` como external table Parquet.
6. O runner apaga o conteudo do prefixo de staging.
7. O statement `CREATE TABLE ... AS SELECT` gera `default.curated_messages_stage` apenas com registros ainda nao presentes na curated.
8. O `INSERT INTO default.curated_messages` move os dados da staging para a tabela final.
9. O `DROP TABLE default.curated_messages_stage` remove apenas o metadado da staging.

## Permissoes Importantes Do Glue Job

Para o fluxo atual, a role do Glue precisa ao menos destas capacidades:

- S3: `s3:GetBucketLocation`, `s3:ListBucket`, `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`
- Athena: `athena:StartQueryExecution`, `athena:GetQueryExecution`, `athena:GetQueryResults`, `athena:StopQueryExecution`, `athena:ListWorkGroups`
- Glue Catalog: `glue:GetDatabase`, `glue:GetDatabases`, `glue:GetTable`, `glue:GetTables`, `glue:GetPartition`, `glue:GetPartitions`, `glue:BatchCreatePartition`, `glue:CreateTable`, `glue:UpdateTable`, `glue:DeleteTable`

Arquivo principal:

- [main.tf](e:/Projetos/Data-journey/infra/terraform/main.tf)

## Como Incrementar Este Processo

### Se quiser manter Hive/Parquet

- manter `raw_bronze_messages` como external table JSON com particao `date`
- manter `curated_messages` como external table Parquet
- substituir o anti-join atual por uma estrategia de deduplicacao mais explicita se o volume crescer
- considerar gravar a staging em prefixo por execucao para reduzir acoplamento com cleanup
- preservar o uso de `{{DATA_BUCKET}}` no SQL para evitar bifurcacao por ambiente

### Se quiser migrar para Iceberg

- separar a migracao em outro arquivo SQL, sem misturar sintaxe Hive e Trino no mesmo script
- validar se o Athena workgroup e o catalogo estao prontos para operacoes Iceberg
- trocar o fluxo de `staging + insert` por `merge` ou estrategia equivalente somente depois da DDL Iceberg estar estabilizada

### Melhorias recomendadas no runner

- parametrizar o prefixo da staging em vez de deixar constante no codigo
- registrar o texto do statement em log estruturado quando falhar
- adicionar limpeza opcional dos paths temporarios do Athena citados em mensagens de erro
- emitir metricas ou contadores por statement executado
- se necessario, evoluir o renderer para suportar placeholders adicionais alem de `{{DATA_BUCKET}}`

## Promocao Para Hom E Prod

1. confirmar que `dev` esta processando mensagens novas ate `default.curated_messages`
2. aplicar Terraform no ambiente alvo
3. publicar o mesmo `runner.py` e o mesmo `insert_curated_messages.sql` no bucket do ambiente alvo
4. validar o Glue Job do ambiente com `aws glue get-job`
5. validar a role/policies do ambiente com `.\scripts\validate-glue-athena-access.ps1`
6. publicar uma mensagem de teste no SNS do ambiente
7. confirmar dados em `bronze/raw`
8. executar o Glue Job manualmente uma vez
9. consultar `default.curated_messages`

Checklist por ambiente:

- bucket do ambiente existe e esta na regiao correta
- role do Glue contem as permissoes de S3, Athena e Glue Catalog listadas acima
- `SQL_S3_URI` e `ScriptLocation` apontam para o bucket do proprio ambiente
- o SQL publicado ainda contem `{{DATA_BUCKET}}` e nao um bucket hardcoded

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
- se o bucket esta na mesma regiao do Glue Job e do Athena

### Athena: `Queries of this type are not supported`

Validar:

- se o `INSERT INTO` esta lendo da mesma tabela de destino
- se a carga incremental foi quebrada em `staging -> insert final`
- se o statement esta tentando usar uma combinacao nao suportada de Hive e Trino

### Athena: `HIVE_PATH_ALREADY_EXISTS`

Validar:

- se o prefixo da staging ainda contem arquivos de execucao anterior
- se o runner publicado no S3 ja contem a limpeza automatica do prefixo

Limpeza manual:

```powershell
aws s3 rm `
  s3://dev-axcloud-lab-sa-east-1-data/tmp/curated-messages-stage/ `
  --recursive `
  --region sa-east-1
```

### Athena: `Unsupported Hive type: timestamp(3) with time zone`

Validar:

- se o `CTAS` esta convertendo `from_iso8601_timestamp(...)` para `timestamp` sem timezone
- se `current_timestamp` esta sendo convertido com `CAST(... AS timestamp)`

### Glue Catalog: `AccessDeniedException`

Validar:

- se a role do Glue tem `glue:GetPartition`
- se a role do Glue tem `glue:DeleteTable`
- se o `terraform apply` foi executado apos alterar a policy

Hotfix via AWS CLI:

- baixar a inline policy atual
- adicionar apenas a action faltante
- reenviar com `aws iam put-role-policy`

### Athena: erro de parser SQL

Validar:

- se a DDL raw esta 100% Hive (`CREATE EXTERNAL TABLE`, `ROW FORMAT SERDE`, `PARTITIONED BY`)
- se a DDL curated nao mistura Iceberg/Trino com Hive no mesmo statement
- quoting de campos como `"from"` em `SELECT`
- uso de crase apenas onde Hive aceita, evitando crase em expressoes do `SELECT`

### Deploy: warning de Node 20

Os workflows ja foram ajustados com:

- `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true`

## Documentos de Apoio

- [project-assessment.md](e:/Projetos/Data-journey/docs/project-assessment.md)
- [execution-plan.md](e:/Projetos/Data-journey/docs/execution-plan.md)

## Status Atual

O projeto esta com o fluxo ponta a ponta funcional em `dev`, incluindo carga da camada curated via Glue + Athena. O principal foco agora e reduzir acoplamento operacional, consolidar a estrategia final da tabela curated e transformar os aprendizados de troubleshooting em automatizacoes permanentes.
