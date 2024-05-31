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
) 
PARTITIONED BY (insert_date DATE) 
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
STORED AS textfile 
LOCATION 's3://data-lake-bucket/stage/top_1000_youtubers/' 
TABLE PROPERTIES ('skip.header.line.count' = '1');