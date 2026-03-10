variable "bucket_name" {
  type = string
}

variable "create_data_bucket" {
  type        = bool
  description = "Quando true, cria o bucket S3 de dados. Quando false, reutiliza bucket existente."
  default     = true
}

variable "environment" {
    type = string
    description = "Ambiente de deploy (ex: dev, hom, prod)"
}

variable "aws_region" {
    type = string
    description = "Região AWS onde os recursos serão provisionados"
    default = "sa-east-1"
}

variable "account_id" {
  type = string
  description = "ID da conta na AWS"
  default = "string"
}
