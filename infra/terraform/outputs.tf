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

output "lambda_function_name" {
  description = "Nome da função Lambda de ingestão"
  value       = aws_lambda_function.ingest.function_name
}

output "lambda_function_arn" {
  description = "ARN da função Lambda"
  value       = aws_lambda_function.ingest.arn
}

output "lambda_invoke_arn" {
  description = "ARN de invocação da Lambda"
  value       = aws_lambda_function.ingest.invoke_arn
}

output "lambda_role_arn" {
  description = "ARN da role IAM da Lambda"
  value       = aws_iam_role.lambda_exec.arn
}

output "glue_job_name" {
  description = "Nome do Glue Job"
  value       = aws_glue_job.athena_exec.name
}

output "glue_job_arn" {
  description = "ARN do Glue Job"
  value       = "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:job/${aws_glue_job.athena_exec.name}"
}

output "sns_topic_arn" {
  description = "ARN do tópico SNS de ingestão"
  value       = aws_sns_topic.ingest.arn
}

output "sns_topic_name" {
  description = "Nome do tópico SNS"
  value       = aws_sns_topic.ingest.name
}