variable "bucket_name" {
  type        = string
  description = "Nome do bucket S3 de dados"

  validation {
    condition     = length(var.bucket_name) > 0
    error_message = "O nome do bucket nao pode ser vazio."
  }
}

variable "create_data_bucket" {
  type        = bool
  description = "Quando true, cria o bucket S3. Quando false, reutiliza existente."
  default     = true
}

variable "environment" {
  type        = string
  description = "Ambiente de deploy (dev, hom, prod)"

  validation {
    condition     = contains(["dev", "hom", "prod"], var.environment)
    error_message = "O ambiente deve ser: dev, hom ou prod."
  }
}

variable "aws_region" {
  type        = string
  description = "Regiao AWS para o deployment"
  default     = "sa-east-1"
}

variable "lambda_function_name" {
  type        = string
  description = "Nome da funcao Lambda"
}

variable "lambda_handler" {
  type        = string
  description = "Handler da Lambda (ex: main.handler)"
  default     = "main.handler"
}

variable "lambda_timeout" {
  type        = number
  description = "Timeout da Lambda em segundos"
  default     = 60

  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "O timeout deve estar entre 1 e 900 segundos."
  }
}

variable "lambda_memory_size" {
  type        = number
  description = "Memoria alocada para a Lambda em MB"
  default     = 128

  validation {
    condition     = contains([128, 256, 512, 1024, 2048, 3008], var.lambda_memory_size)
    error_message = "O memory_size deve ser: 128, 256, 512, 1024, 2048 ou 3008."
  }
}

variable "lambda_s3_key" {
  type        = string
  description = "Caminho do ZIP da Lambda no bucket S3 (ex: lambda/lambda.zip)"
}

variable "sns_topic_arn" {
  type        = string
  description = "ARN do topico SNS usado pela Lambda"
  default     = ""
}

variable "glue_job_name" {
  type        = string
  description = "Nome do Glue Job acionado pela Lambda"
  default     = ""
}