CREATE EXTERNAL TABLE IF NOT EXISTS default.raw_bronze_messages (
  message_id string,
  environment string,
  ingested_at string,
  payload struct<hello:string,`from`:string>,
  source struct<source_type:string,topic_arn:string,subject:string,published_at:string>
)
PARTITIONED BY (date string)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
LOCATION 's3://{{DATA_BUCKET}}/bronze/raw/';

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
LOCATION 's3://{{DATA_BUCKET}}/curated/messages/'
TBLPROPERTIES ('parquet.compress'='SNAPPY');

DROP TABLE IF EXISTS default.curated_messages_stage;

CREATE TABLE default.curated_messages_stage
WITH (
  format = 'PARQUET',
  external_location = 's3://{{DATA_BUCKET}}/tmp/curated-messages-stage/'
)
AS
SELECT
  raw.message_id,
  raw.environment,
  CAST(at_timezone(from_iso8601_timestamp(raw.ingested_at), 'UTC') AS timestamp) AS ingested_at,
  raw.source.source_type AS source_type,
  raw.source.topic_arn AS topic_arn,
  CAST(at_timezone(try(from_iso8601_timestamp(raw.source.published_at)), 'UTC') AS timestamp) AS published_at,
  raw.payload.hello AS hello,
  raw.payload."from" AS origin,
  json_format(CAST(raw.payload AS json)) AS payload_json,
  CAST(current_timestamp AS timestamp) AS processed_at,
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
