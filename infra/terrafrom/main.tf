resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.environment}-axcloud-lab-${var.aws_region}-data"
  
  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
  
}