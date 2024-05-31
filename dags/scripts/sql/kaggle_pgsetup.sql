DROP SCHEMA IF EXISTS kaggle CASCADE;
CREATE SCHEMA kaggle;

CREATE TABLE kaggle.top_1000_youtubers (
    rank INT,
    youtuber VARCHAR(255),
    subscribers FLOAT,
    video_views FLOAT,
    category VARCHAR(255),
    title VARCHAR(255),
    uploads INT,
    country VARCHAR(255),
    abbreviation VARCHAR(2),
    channel_type VARCHAR(255),
    video_views_rank FLOAT,
    country_rank FLOAT,
    channel_type_rank FLOAT,
    video_views_for_last_30_days FLOAT,
    lowest_monthly_earnings FLOAT,
    highest_monthly_earnings FLOAT,
    lowest_yearly_earnings FLOAT,
    highest_yearly_earnings FLOAT,
    subscribers_for_last_30_days FLOAT,
    created_year FLOAT,
    created_month VARCHAR(10),
    created_date FLOAT,
    gross_tertiary_education_enrollment_percent FLOAT,
    population FLOAT,
    unemployment_rate FLOAT,
    urban_population FLOAT,
    latitude FLOAT,
    longitude FLOAT
);

COPY kaggle.top_1000_youtubers(rank, youtuber, subscribers, video_views, category, title, uploads, country, abbreviation, channel_type, video_views_rank,
    country_rank, channel_type_rank, video_views_for_last_30_days, lowest_monthly_earnings, highest_monthly_earnings,
    lowest_yearly_earnings, highest_yearly_earnings, subscribers_for_last_30_days, created_year, created_month, created_date,
    gross_tertiary_education_enrollment_percent, population, unemployment_rate, urban_population, latitude, longitude) 
FROM '/input_data/Cleaned_Global_YouTube_Statistics.csv' DELIMITER ',' CSV HEADER ;