-- This is run as part of the setup_infra.sh script
CREATE EXTERNAL SCHEMA spectrum
FROM DATA CATALOG DATABASE 'spectrumdb' iam_role 'arn:aws:iam::"$AWS_ID":role/"$IAM_ROLE_NAME"' CREATE EXTERNAL DATABASE IF NOT EXISTS;
DROP TABLE IF EXISTS spectrum.top_1000_youtubers_staging;
CREATE EXTERNAL TABLE spectrum.top_1000_youtubers_staging (
    rank INT,
    youtuber VARCHAR(255),
    subscribers INT,
    video_views NUMERIC,
    category VARCHAR(255),
    title VARCHAR(255),
    uploads INT,
    country VARCHAR(255),
    abbreviation VARCHAR(2),
    channel_type VARCHAR(255)
) PARTITIONED BY (insert_date DATE) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS textfile LOCATION 's3://"$1"/stage/top_1000_youtubers/' TABLE PROPERTIES ('skip.header.line.count' = '1');

);