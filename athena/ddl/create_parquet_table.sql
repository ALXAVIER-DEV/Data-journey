CREATE TABLE default.curated_messages (
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
PARTITIONED BY (`date`)
LOCATION 's3://{{DATA_BUCKET}}/curated/messages/'
TBLPROPERTIES (
  'table_type'='ICEBERG',
  'format'='PARQUET',
  'write_compression'='SNAPPY',
  'optimize_rewrite_delete_file_threshold'='10'
);
