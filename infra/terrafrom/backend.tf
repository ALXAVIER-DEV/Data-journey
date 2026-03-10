data "aws_s3_bucket" "existing_data_bucket" {
  count  =  var.environment == "dev" ? 1 : 0
  bucket = var.bucket_name
}


