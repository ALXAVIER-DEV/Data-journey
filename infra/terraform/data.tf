data "aws_caller_identity" "current" {}


data "aws_s3_bucket" "existing_data_bucket" {
  count  = var.create_data_bucket ? 0 : 1
  bucket = var.bucket_name

}


# ============================================================
# IAM Role — Lambda
# ============================================================
resource "aws_iam_role" "lambda_exec" {
  name = "${var.lambda_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.lambda_function_name}-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "${var.lambda_function_name}-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/*"
      },
      {
        Sid      = "SNSAccess"
        Effect   = "Allow"
        Action   = ["sns:Publish", "sns:Subscribe"]
        Resource = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Sid    = "GlueAccess"
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun"
        ]
        Resource = "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:job/*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# ============================================================
# Lambda Function
# ============================================================
resource "aws_lambda_function" "ingest" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.12"
  handler       = var.lambda_handler
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  s3_bucket = var.bucket_name
  s3_key    = var.lambda_s3_key

  environment {
    variables = {
      ENVIRONMENT    = var.environment
      AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
      S3_BUCKET      = var.bucket_name
      SNS_TOPIC_ARN  = var.sns_topic_arn
      GLUE_JOB_NAME  = var.glue_job_name
    }
  }

  tags = {
    Name        = var.lambda_function_name
    Environment = var.environment
  }

  depends_on = [aws_iam_role_policy.lambda_permissions]
}