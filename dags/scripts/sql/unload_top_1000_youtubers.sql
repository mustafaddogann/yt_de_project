COPY (
       select 
              rank,
              youtuber,
              subscribers,
              video_views,
              category,
              title,
              uploads,
              country,
              abbreviation,
              channel_type 
       from kaggle.top_1000_youtubers 
) TO '{{ params.top_1000_youtubers }}' WITH (FORMAT CSV, HEADER);