CREATE EXTERNAL TABLE IF NOT EXISTS default.curated_messages (
  message_id string,
  environment string,
  ingested_at timestamp,
  source_type string,
  topic_arn string,
  published_at timestamp,
  hello string,
  origin string,
  payload_json string,
  processed_at timestamp
)
PARTITIONED BY (date string)
STORED AS PARQUET
LOCATION 's3://dev-axcloud-lab-sa-east-1-data/curated/messages/'
TBLPROPERTIES ('parquet.compression'='SNAPPY');
