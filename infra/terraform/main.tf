resource "aws_s3_bucket" "data_bucket" {
  count  = var.create_data_bucket ? 1 : 0
  bucket = var.bucket_name
  lifecycle {
  prevent_destroy = true
  ignore_changes  = [bucket]  
  }
  
  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
  
}
