resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.environment}-axcloud-lab-sa-east-1-data"
  
  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
  
}