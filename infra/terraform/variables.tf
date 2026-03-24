variable "project_name" {
  type        = string
  description = "Nome base do projeto"

  validation {
    condition     = length(trim(var.project_name, " ")) > 0
    error_message = "O project_name nao pode ser vazio."
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
  description = "Caminho do ZIP da Lambda no bucket S3"

  validation {
    condition     = length(trim(var.lambda_s3_key, " ")) > 0
    error_message = "O lambda_s3_key nao pode ser vazio."
  }
}

variable "glue_script_s3_key" {
  type        = string
  description = "Caminho do script Glue no bucket S3"
  default     = "glue/python_shell/runner.py"

  validation {
    condition     = length(trim(var.glue_script_s3_key, " ")) > 0
    error_message = "O glue_script_s3_key nao pode ser vazio."
  }
}
variable "glue_log_retention_in_days" {
  type        = number
  description = "Retencao em dias dos logs do Glue no CloudWatch"
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.glue_log_retention_in_days)
    error_message = "O glue_log_retention_in_days deve ser um valor valido do CloudWatch Logs."
  }
}
