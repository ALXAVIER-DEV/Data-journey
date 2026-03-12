# Project Assessment

## Executive Summary

O repositório já tem uma base boa de infraestrutura e automação para um laboratório de ingestão serverless na AWS, mas o fluxo descrito na documentação ainda não está fechado ponta a ponta no código versionado.

Hoje o projeto está mais forte em:

- provisionamento com Terraform
- deploy com GitHub Actions usando OIDC
- execução de SQL no Athena via Glue Python Shell

Os maiores gaps atuais são:

- a aplicação de ingestão não está consistente com a arquitetura descrita
- a documentação não reflete o estado real do código
- faltam testes e validações automáticas
- o backlog técnico não está materializado no repositório

## Arquitetura Encontrada

### Camadas do repositório

- `.github/workflows`: pipelines de deploy e Terraform
- `infra/terraform`: provisionamento AWS
- `glue/python_shell/runner.py`: execução de SQL no Athena
- `athena/dml/insert_curated_messages.sql`: transformação para camada curated
- `src/lambda_ingest/lambda-axcloud.py`: função Lambda para execução de queries Athena
- `src/app`: pacote previsto para app Python, mas incompleto no estado atual

### Fluxo realmente implementado no código

1. O workflow de deploy empacota `src/lambda_ingest`.
2. O ZIP da Lambda, o SQL e o script do Glue são enviados para S3.
3. O Terraform provisiona S3, Lambda, SNS e Glue Job.
4. O deploy atualiza o código da Lambda e o script do Glue.
5. Um smoke test publica uma mensagem no SNS.

### Fluxo descrito no README mas não comprovado no repositório

1. SNS para SQS.
2. SQS acionando Lambda.
3. Lambda normalizando evento e gravando JSON em S3 raw.
4. Athena consultando dados raw já materializados no lake.

## Diagnóstico Técnico

### Pontos fortes

- OIDC entre GitHub Actions e AWS já está definido nos workflows.
- O deploy separa upload de artefatos, Terraform e atualização de runtime.
- O Glue runner tem validações mínimas de ambiente e tratamento de erro básico.
- O Terraform usa backend remoto em S3 e tenta habilitar locking.

### Gaps e inconsistências

#### 1. Aplicação principal incompleta

- `src/app/handler.py` está vazio.
- `src/app/normalizer.py` não possui conteúdo útil no estado atual.
- `src/app/s3_writer.py` existe, mas não aparece integrado ao fluxo principal.

Impacto:

- o fluxo de ingestão descrito no projeto não pode ser validado localmente a partir desse pacote
- a responsabilidade da Lambda de ingestão está difusa

#### 2. Mismatch entre documentação, empacotamento e handler

- o README fala em `handler.py` dentro de `src/lambda_ingest`, mas o arquivo existente é `lambda-axcloud.py`
- o Terraform usa por default `main.handler` em `infra/terraform/variables.tf`
- o workflow empacota `src/lambda_ingest`, mas não há evidência local de um arquivo `main.py`

Impacto:

- alto risco de erro em runtime no deploy da Lambda por handler incorreto

#### 3. Infra não fecha o fluxo SNS -> SQS -> Lambda

Na inspeção do `main.tf`, não apareceram recursos esperados para o pipeline descrito:

- SQS queue
- SNS subscription para SQS
- `aws_lambda_event_source_mapping`
- permissões de consumo da fila

Impacto:

- o smoke test publica no SNS, mas o consumo até a Lambda não está demonstrado no código versionado

#### 4. README desatualizado

O README descreve arquivos e diretórios que não batem com a árvore atual:

- menciona `src/lambda_ingest/handler.py`
- menciona DDLs Athena que não estão presentes
- menciona `ci.yml`, mas existe `ci.txt`

Impacto:

- aumenta custo de onboarding e dificulta planejar próximos passos

#### 5. Higiene de workflows

- existe um arquivo com nome `deploy-hom .yml`, com espaço antes da extensão
- isso tende a gerar confusão operacional e manutenção ruim

#### 6. Falta de testes e quality gates

Não há suíte de testes visível nem pipeline claro de:

- lint
- unit tests
- validação de empacotamento da Lambda
- validação de SQL

Impacto:

- mudanças de infraestrutura e código têm risco alto de regressão silenciosa

## Próximos Passos Recomendados

### Prioridade alta

1. Definir qual é a Lambda principal do projeto e alinhar nome de arquivo, handler e workflow.
2. Implementar de fato o fluxo de ingestão raw para S3 ou ajustar a documentação para o fluxo Athena atual.
3. Completar a infraestrutura de mensageria com SQS e trigger da Lambda, se esse for o desenho desejado.
4. Criar testes mínimos para normalização, persistência e deploy package.

### Prioridade média

1. Atualizar README com arquitetura real, árvore correta e instruções de operação.
2. Organizar os workflows por ambiente e remover inconsistências de naming.
3. Criar observabilidade mínima com logs estruturados e métricas de falha.

### Prioridade baixa

1. Adicionar DDLs do Athena ao repositório.
2. Criar exemplos de payloads e script de teste local.
3. Documentar runbook operacional para deploy e rollback.

## Roadmap Sugerido

### Fase 1. Fechar o core técnico

- consolidar Lambda de ingestão
- corrigir handler e packaging
- completar integração SNS/SQS/Lambda

### Fase 2. Tornar o projeto operável

- README real
- testes
- validações no CI

### Fase 3. Tornar o projeto demonstrável

- observabilidade
- DDL/DML completos
- exemplos e documentação de uso

## Limitações desta análise

- Não houve leitura direta do board ágil no GitHub a partir deste ambiente.
- O diagnóstico foi feito sobre o código local versionado em `E:\Projetos\Data-journey`.
- Os cards gerados foram derivados do estado atual do repositório e não de itens já existentes no seu board.
