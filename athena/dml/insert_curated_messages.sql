CREATE TABLE default.raw_bronze_messages (
  message_id string,
  environment string,
  ingested_at string,
  payload row(hello varchar, "from" varchar),
  source row(source_type varchar, topic_arn varchar, subject varchar, published_at varchar),
  date string
)
WITH (
  external_location = 's3://dev-axcloud-lab-sa-east-1-data/bronze/raw/',
  format = 'JSON',
  partitioned_by = ARRAY['date']
);

MSCK REPAIR TABLE default.raw_bronze_messages;

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
LOCATION 's3://dev-axcloud-lab-sa-east-1-data/curated/messages/'
TBLPROPERTIES (
  'table_type'='ICEBERG',
  'format'='PARQUET',
  'write_compression'='SNAPPY',
  'partitioning'='ARRAY[''date'']'
);

DROP TABLE IF EXISTS default.curated_messages_stage;

CREATE TABLE default.curated_messages_stage
WITH (
  format = 'PARQUET'
) AS
SELECT
  raw.message_id,
  raw.environment,
  from_iso8601_timestamp(raw.ingested_at) AS ingested_at,
  raw.source.source_type AS source_type,
  raw.source.topic_arn AS topic_arn,
  try(from_iso8601_timestamp(raw.source.published_at)) AS published_at,
  raw.payload.hello AS hello,
  raw.payload."from" AS origin,
  json_format(CAST(raw.payload AS json)) AS payload_json,
  current_timestamp AS processed_at,
  raw.date AS date
FROM (
  SELECT
    raw.*,
    row_number() OVER (
      PARTITION BY raw.message_id
      ORDER BY raw.ingested_at DESC
    ) AS row_num
  FROM default.raw_bronze_messages raw
) raw
LEFT JOIN default.curated_messages curated
  ON raw.message_id = curated.message_id
WHERE raw.row_num = 1
  AND curated.message_id IS NULL;

INSERT INTO default.curated_messages
SELECT
  message_id,
  environment,
  ingested_at,
  source_type,
  topic_arn,
  published_at,
  hello,
  origin,
  payload_json,
  processed_at,
  date
FROM default.curated_messages_stage;

DROP TABLE IF EXISTS default.curated_messages_stage;
