CREATE EXTERNAL TABLE IF NOT EXISTS default.raw_bronze_messages (
  message_id string,
  environment string,
  ingested_at string,
  payload struct<hello:string,`from`:string>,
  source struct<source_type:string,topic_arn:string,subject:string,published_at:string>
)
PARTITIONED BY (date string)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://dev-axcloud-lab-sa-east-1-data/bronze/raw/'
TBLPROPERTIES ('has_encrypted_data'='false');

MSCK REPAIR TABLE default.raw_bronze_messages;

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

INSERT INTO default.curated_messages
SELECT
  raw.message_id,
  raw.environment,
  from_iso8601_timestamp(raw.ingested_at) AS ingested_at,
  raw.source.source_type AS source_type,
  raw.source.topic_arn AS topic_arn,
  try(from_iso8601_timestamp(raw.source.published_at)) AS published_at,
  raw.payload.hello AS hello,
  raw.payload.`from` AS origin,
  json_format(CAST(raw.payload AS json)) AS payload_json,
  current_timestamp AS processed_at,
  raw.date AS date
FROM default.raw_bronze_messages raw
LEFT JOIN default.curated_messages curated
  ON raw.message_id = curated.message_id
WHERE curated.message_id IS NULL;
