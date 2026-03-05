# Data-journey

AWS Serverless Data Ingestion Lab

Projeto de laboratório para estudo de ingestão de dados serverless na AWS, utilizando arquitetura orientada a eventos, persistência em Amazon S3, processamento via AWS Athena, execução de tarefas com AWS Glue Python Shell e pipeline CI/CD com GitHub Actions.

O objetivo é demonstrar, de forma prática, um fluxo completo de Data Ingestion → Data Lake → Query Engine, incluindo automação de deploy e boas práticas de engenharia de dados.


## Objetivos do Projeto

Este laboratório foi desenvolvido com os seguintes objetivos:

Aprender os principais serviços serverless da AWS

Implementar um fluxo de ingestão orientado a eventos

Persistir dados no S3 organizados por partições de data

Consultar dados utilizando Athena

Automatizar deploy utilizando GitHub Actions

Utilizar OIDC para autenticação segura entre GitHub e AWS

Estruturar um pipeline semelhante a ambientes reais de Data Platform

Producer
   │
   ▼
SNS Topic
   │
   ▼
SQS Queue
   │
   ▼
Lambda (transformação)
   │
   ▼
S3 Data Lake
   │
   ├── raw/json/date=YYYYMMDD/
   │
   ▼
Athena (DDL + DML)
   │
   ▼
Parquet Curated Layer
   │
   ▼
Analytics / BI

Serviços AWS Utilizados

Este projeto utiliza os seguintes serviços da AWS:

| Serviço               | Função                        |
| --------------------- | ----------------------------- |
| Amazon S3             | Armazenamento do Data Lake    |
| Amazon SNS            | Publicação de eventos         |
| Amazon SQS            | Fila de mensagens             |
| AWS Lambda            | Processamento serverless      |
| AWS Athena            | Query engine SQL              |
| AWS Glue Python Shell | Execução de jobs de automação |
| Amazon CloudWatch     | Logs e observabilidade        |
| IAM                   | Controle de acesso            |
| GitHub Actions        | CI/CD                         |


Fluxo de Ingestão de Dados

Uma mensagem é publicada em um SNS Topic

O SNS envia a mensagem para uma fila SQS

A Lambda é acionada pela SQS

A Lambda transforma a mensagem em JSON estruturado

O JSON é salvo no S3 Data Lake


Estrutura do Repositório

repo/

src/
 └ lambda_ingest/
     └ handler.py

glue/
 └ python_shell/
     └ runner.py

athena/
 ├ ddl/
 │   ├ create_raw_table.sql
 │   └ create_parquet_table.sql
 │
 └ dml/
     └ insert_curated_messages.sql

.github/
 └ workflows/
     ├ ci.yml
     ├ deploy-dev.yml
     └ deploy-prod.yml

Estrutura do Data Lake

Camadas utilizadas:


S3
│
├ landing/
│   └ raw/
│       └ date=YYYYMMDD/
│           └ file.json
│
├ curated/
│   └ parquet/
│
└ athena-results/
