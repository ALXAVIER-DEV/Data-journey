CREATE TABLE IF NOT EXISTS default.raw_bronze_messages (
  message_id varchar,
  environment varchar,
  ingested_at varchar,
  payload row(hello varchar, "from" varchar),
  source row(source_type varchar, topic_arn varchar, subject varchar, published_at varchar),
  date varchar
)
WITH (
  external_location = 's3://dev-axcloud-lab-sa-east-1-data/bronze/raw/',
  format = 'JSON',
  partitioned_by = ARRAY['date']
);
