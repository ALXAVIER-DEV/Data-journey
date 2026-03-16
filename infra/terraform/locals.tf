locals {
  prefix = "${var.environment}-${var.project_name}"

  bucket_name          = "${local.prefix}-${var.aws_region}-data"
  lambda_function_name = "${local.prefix}-lambda-ingest"
  glue_job_name        = "${local.prefix}-glue-shell-athena-exec"
  sns_topic_name       = "${local.prefix}-topic-ingest"

  lambda_role_name = "${local.lambda_function_name}-role"
  glue_role_name   = "${local.glue_job_name}-role"

  bronze_prefix = "bronze"
  silver_prefix = "silver"
  gold_prefix   = "gold"

  effective_bucket_name = var.create_data_bucket
  ? aws_s3_bucket.data_bucket[0].bucket
  : data.aws_s3_bucket.existing_data_bucket[0].bucket
}

