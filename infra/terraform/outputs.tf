# ============================================================
# S3
# ============================================================
output "data_bucket_name" {
  description = "Nome do bucket S3 de dados"
  value       = var.create_data_bucket ? aws_s3_bucket.data_bucket[0].id : ""
}

output "data_bucket_arn" {
  description = "ARN do bucket S3 de dados"
  value       = var.create_data_bucket ? aws_s3_bucket.data_bucket[0].arn : ""
}

output "data_bucket_region" {
  description = "Região do bucket S3"
  value       = var.create_data_bucket ? aws_s3_bucket.data_bucket[0].region : ""
}

# ============================================================
# Contexto do deployment
# ============================================================
output "aws_account_id" {
  description = "ID da conta AWS"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "Região AWS do deployment"
  value       = var.aws_region
}

output "environment" {
  description = "Ambiente do deployment"
  value       = terraform.workspace
}