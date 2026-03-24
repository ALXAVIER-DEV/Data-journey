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
  description = "Regiao do bucket S3"
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
  description = "Regiao AWS do deployment"
  value       = var.aws_region
}

output "environment" {
  description = "Ambiente do deployment"
  value       = terraform.workspace
}

output "lambda_function_name" {
  description = "Nome da funcao Lambda de ingestao"
  value       = aws_lambda_function.ingest.function_name
}

output "lambda_function_arn" {
  description = "ARN da funcao Lambda"
  value       = aws_lambda_function.ingest.arn
}

output "lambda_invoke_arn" {
  description = "ARN de invocacao da Lambda"
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
  description = "ARN do topico SNS de ingestao"
  value       = aws_sns_topic.ingest.arn
}

output "sns_topic_name" {
  description = "Nome do topico SNS"
  value       = aws_sns_topic.ingest.name
}

output "sqs_queue_name" {
  description = "Nome da fila SQS de ingestao"
  value       = aws_sqs_queue.ingest.name
}

output "sqs_queue_arn" {
  description = "ARN da fila SQS de ingestao"
  value       = aws_sqs_queue.ingest.arn
}

output "sqs_queue_url" {
  description = "URL da fila SQS de ingestao"
  value       = aws_sqs_queue.ingest.url
}

output "glue_log_group_name" {
  description = "Nome do CloudWatch Log Group do Glue"
  value       = local.glue_log_group_name
}
