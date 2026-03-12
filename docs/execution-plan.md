# Execution Plan

## Objetivo

Transformar o estado atual do projeto em um pipeline funcional, testável e demonstrável, reduzindo primeiro os riscos estruturais que hoje impedem evolução segura.

## Estratégia

A execução foi organizada em sprints curtas com foco em dependências técnicas reais. A prioridade não é cosmética; primeiro fecha-se o core operacional, depois a qualidade, e só então documentação expandida e observabilidade mais completa.

## Ordem recomendada

1. Alinhar Lambda principal, handler e empacotamento.
2. Implementar o fluxo de ingestão raw para S3.
3. Provisionar SQS e trigger da Lambda no Terraform.
4. Criar testes mínimos e quality gates no CI.
5. Atualizar README e padronizar workflows.
6. Adicionar observabilidade e completar artefatos Athena.

## Dependências entre cards

### Base estrutural

- `Alinhar Lambda principal, handler e empacotamento` é pré-requisito para quase todo o resto.
- `Implementar fluxo de ingestão raw para S3` depende do item acima.
- `Provisionar SQS e trigger da Lambda no Terraform` depende do desenho final da Lambda de ingestão.

### Qualidade

- `Criar suíte mínima de testes para app e empacotamento` depende de a estrutura da aplicação estar estabilizada.

### Organização e operação

- `Atualizar README para refletir a arquitetura real` depende das decisões tomadas nas sprints anteriores.
- `Padronizar workflows por ambiente e nomenclatura` pode começar cedo, mas deve ser finalizado depois de estabilizar o deploy.
- `Adicionar observabilidade mínima para ingestão e Glue` depende do fluxo operacional estar funcional.
- `Versionar DDLs e exemplos operacionais do Athena` depende da definição final da camada raw e curated.

## Sprint 1

### Objetivo

Remover a ambiguidade do entrypoint da Lambda e garantir que o deploy aponte para um artefato válido.

### Cards

- Alinhar Lambda principal, handler e empacotamento

### Entregáveis

- definição de qual arquivo é a Lambda oficial
- atualização do handler no Terraform
- ajuste do workflow de deploy para o artefato correto
- validação manual de empacotamento e atualização da Lambda

### Critério de pronto

- existe um único entrypoint oficial
- o deploy não depende de convenção implícita ou arquivo inexistente
- o nome do handler está consistente entre código, Terraform e workflow

### Riscos

- o código atual da Lambda pode representar outro caso de uso, mais próximo de Athena query runner do que ingestão
- pode ser necessário decidir entre reaproveitar `src/lambda_ingest` ou migrar para `src/app`

## Sprint 2

### Objetivo

Fechar o fluxo funcional de ingestão até a camada raw do S3.

### Cards

- Implementar fluxo de ingestão raw para S3
- Provisionar SQS e trigger da Lambda no Terraform

### Entregáveis

- normalizador de payload
- escrita no S3 com particionamento por data
- fila SQS no Terraform
- subscription SNS -> SQS
- trigger SQS -> Lambda
- permissões IAM mínimas necessárias

### Critério de pronto

- uma mensagem publicada no SNS percorre o pipeline até gerar arquivo raw no S3
- o artefato salvo no S3 segue convenção de chave definida
- erros de payload inválido são tratados de forma explícita

### Riscos

- a infraestrutura atual pode exigir refatoração do smoke test
- a role atual da Lambda pode estar ampla demais ou insuficiente para o desenho final

## Sprint 3

### Objetivo

Criar segurança mínima para evolução do projeto sem regressões silenciosas.

### Cards

- Criar suíte mínima de testes para app e empacotamento

### Entregáveis

- testes unitários para normalização
- testes para escrita em S3 com mocks
- validação do pacote da Lambda
- execução de testes em pull requests

### Critério de pronto

- mudanças no código principal falham cedo quando quebram contrato
- o pipeline executa validações antes do deploy

### Riscos

- ausência de estrutura Python consolidada pode exigir pequena reorganização de pastas

## Sprint 4

### Objetivo

Sincronizar operação e documentação com o sistema real.

### Cards

- Atualizar README para refletir a arquitetura real
- Padronizar workflows por ambiente e nomenclatura

### Entregáveis

- README atualizado
- árvore do projeto correta
- instruções de deploy e operação revisadas
- workflows renomeados e padronizados

### Critério de pronto

- uma pessoa nova consegue entender o fluxo sem inferências
- não existem nomes ambíguos ou arquivos obsoletos nos workflows

### Riscos

- se a arquitetura mudar durante sprints anteriores, a documentação terá de ser fechada apenas no final

## Sprint 5

### Objetivo

Tornar o projeto observável e reproduzível como laboratório de dados.

### Cards

- Adicionar observabilidade mínima para ingestão e Glue
- Versionar DDLs e exemplos operacionais do Athena

### Entregáveis

- logs estruturados
- troubleshooting básico documentado
- DDLs raw e curated
- exemplos de payload e uso analítico

### Critério de pronto

- o pipeline possui trilha mínima de diagnóstico
- a camada analítica pode ser reproduzida sem conhecimento tácito

### Riscos

- se a modelagem raw mudar, os DDLs também precisarão ser revisados

## Definição de pronto global

O projeto pode ser considerado em um estado minimamente consistente quando:

- o deploy da Lambda está correto e reproduzível
- o fluxo `SNS -> SQS -> Lambda -> S3 raw` funciona
- o Terraform representa a arquitetura publicada
- há testes mínimos cobrindo o núcleo da ingestão
- o README descreve o que de fato existe

## Recomendação prática

Se o objetivo for ganhar tração rápida no board, mova apenas os cards da Sprint 1 e Sprint 2 para `Ready`. Os demais devem ficar em `Backlog` até a arquitetura central estar fechada, para evitar retrabalho e documentação prematura.
