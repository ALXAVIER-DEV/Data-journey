variable "bucket_name" {
  type = string
}

variable "environment" {
    type = string
    description = "Ambiente de deploy (ex: dev, hom, prod)"
}