data "aws_s3_bucket" "existing_data_bucket" {
  count  = var.create_data_bucket ? 0 : 1
  bucket = var.bucket_name
}
