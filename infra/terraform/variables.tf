variable "bucket_name" {
  type        = string
  description = "Nome do bucket S3 de dados"

  validation {
    condition     = length(var.bucket_name) > 0
    error_message = "O nome do bucket não pode ser vazio."
  }
}

variable "create_data_bucket" {
  type        = bool
  description = "Quando true, cria o bucket S3 de dados. Quando false, reutiliza bucket existente."
  default     = true
}

variable "environment" {
  type        = string
  description = "Ambiente de deploy (ex: dev, hom, prod)"

  validation {
    condition     = contains(["dev", "hom", "prod"], var.environment)
    error_message = "O ambiente deve ser um dos valores: dev, hom, prod."
  }
}

variable "aws_region" {
  type        = string
  description = "Região AWS onde os recursos serão provisionados"
  default     = "sa-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "A região deve estar no formato AWS válido (ex: sa-east-1, us-east-1)."
  }
}