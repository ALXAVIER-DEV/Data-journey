environment        = "dev"
project_name       = "axcloud-lab"
aws_region         = "sa-east-1"
create_data_bucket = true

lambda_handler     = "main.handler"
lambda_timeout     = 60
lambda_memory_size = 128
lambda_s3_key      = "lambda/lambda.zip"
glue_script_s3_key = "glue/python_shell/runner.py"
