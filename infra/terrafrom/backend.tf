data "aws_s3_bucket" "existing_data_bucket" {
  count  =  var.environment == "dev" ? 1 : 0  || var.create_data_bucket ? 0 : 1
  bucket = var.bucket_name
}


