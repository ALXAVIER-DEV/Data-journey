CREATE TABLE IF NOT EXISTS default.raw_bronze_messages (
  message_id string,
  environment string,
  ingested_at string,
  payload struct<hello:string,from:string>,
  source struct<source_type:string,topic_arn:string,subject:string,published_at:string>,
  date string
)
WITH (
  external_location = 's3://dev-axcloud-lab-sa-east-1-data/bronze/raw/',
  format = 'JSON',
  partitioned_by = date
);
