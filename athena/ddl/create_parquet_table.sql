CREATE TABLE IF NOT EXISTS default.curated_messages (
  message_id string,
  environment string,
  ingested_at timestamp,
  source_type string,
  topic_arn string,
  published_at timestamp,
  hello string,
  origin string,
  payload_json string,
  processed_at timestamp,
  date string
)
LOCATION 's3://dev-axcloud-lab-sa-east-1-data/curated/messages/'
TBLPROPERTIES (
  'table_type'='ICEBERG',
  'format'='PARQUET',
  'write_compression'='SNAPPY',
  'partitioning'='ARRAY[''date'']'
);
