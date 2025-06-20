-- ###############################################################
-- # Project: Cyclistic Bike-Share: Casual to Member Conversion Strategy
-- # Author: [Your Name]
-- # Date: [Current Date, e.g., June 20, 2025]
-- # Tool: Google BigQuery SQL
-- # Dataset: `cyclistic_data_analysis`
-- # Description: This script performs comprehensive data preprocessing (cleaning, feature engineering),
-- #              merging of monthly trip data, and aggregation for analysis. The goal is to identify
-- #              rider behavior patterns to inform strategies for converting casual riders into annual members.
-- #
-- # Data Pipeline Overview:
-- # 1. `_raw` tables: Initial raw data uploaded after basic Excel cleaning.
-- # 2. `_pr` tables: Created by processing `_raw` tables, calculating features like ride length,
-- #    day of week, and hour of day, and applying initial SQL-based cleaning.
-- # 3. `all_merged_trip_data_pr`: A union of all `_pr` monthly tables into a single comprehensive table,
-- #    which serves as the direct source for all analytical aggregations.
-- ###############################################################


-- ###############################################################
-- # SECTION 1: Data Preprocessing and Merging Pipeline
-- # Purpose: Demonstrate the full data preparation from raw input to a merged,
-- #          feature-rich dataset ready for direct analysis.
-- ###############################################################

-- 1.1 Example: Transform Raw Monthly Data to Processed Data (`trip_data_XX_2024_pr`)
-- This query shows the detailed cleaning and feature engineering process applied to each raw monthly table
-- (e.g., `cyclistic_data_analysis.trip_data_01_2024_raw`) to create its processed version (`cyclistic_data_analysis.trip_data_01_2024_pr`).
-- This specific transformation was performed individually for each raw monthly file
-- (`cyclistic_data_analysis.trip_data_01_2024_raw` through `cyclistic_data_analysis.trip_data_06_2024_raw`) to produce
-- `cyclistic_data_analysis.trip_data_01_2024_pr`, `cyclistic_data_analysis.trip_data_02_2024_pr`, ..., `cyclistic_data_analysis.trip_data_06_2024_pr`.

CREATE OR REPLACE TABLE `cyclistic_data_analysis.trip_data_01_2024_pr` AS
SELECT
    ride_id,
    rideable_type,
    started_at,
    ended_at,
    start_station_name,
    end_station_name,
    start_lat,
    start_lng,
    end_lat,
    end_lng,
    member_casual,
    -- Calculated Fields, using DATETIME_DIFF as in your original file 
    DATETIME_DIFF(ended_at, started_at, SECOND) AS ride_length_seconds,
    DATETIME_DIFF(ended_at, started_at, MINUTE) AS ride_length_minutes,
    -- Extract day of the week as a full name (e.g., 'Monday')
    FORMAT_TIMESTAMP('%A', started_at) AS day_of_week_name,
    -- Extract day of the week as a number (0=Sunday, 6=Saturday) 
    FORMAT_TIMESTAMP('%w', started_at) AS day_of_week_num,
    -- Extract the hour of the day (0-23) for hourly trend analysis 
    EXTRACT(HOUR FROM started_at) AS start_hour_of_day,
    -- Extract the month in YYYY-MM format 
    FORMAT_TIMESTAMP('%Y-%m', started_at) AS ride_month
FROM
    `cyclistic_data_analysis.trip_data_01_2024_raw` -- Source is the raw monthly table
WHERE
    -- Apply cleaning filters as in your original file's `all_divvy_trips_processed` creation:
    DATETIME_DIFF(ended_at, started_at, SECOND) > 0 -- Filter out rides with zero or negative duration
    AND start_station_name IS NOT NULL
    AND end_station_name IS NOT NULL
    AND start_lat IS NOT NULL
    AND start_lng IS NOT NULL
    AND end_lat IS NOT NULL
    AND end_lng IS NOT NULL
    AND started_at IS NOT NULL
    AND ended_at IS NOT NULL
;


-- 1.2 Merge All Monthly Processed Tables (`_pr` tables)
-- This query combines all individual monthly processed trip data tables (e.g., `trip_data_01_2024_pr` to `trip_data_06_2024_pr`)
-- from the `cyclistic_data_analysis` dataset into a single, comprehensive master table named `all_merged_trip_data_pr`.
-- This table now contains all the calculated features from the previous `_raw` to `_pr` transformation step,
-- and serves as the direct source for all analytical queries in SECTION 2.
CREATE OR REPLACE TABLE `cyclistic_data_analysis.all_merged_trip_data_pr` AS
SELECT * FROM `cyclistic_data_analysis.trip_data_01_2024_pr`
UNION ALL
SELECT * FROM `cyclistic_data_analysis.trip_data_02_2024_pr`
UNION ALL
SELECT * FROM `cyclistic_data_analysis.trip_data_03_2024_pr`
UNION ALL
SELECT * FROM `cyclistic_data_analysis.trip_data_04_2024_pr`
UNION ALL
SELECT * FROM `cyclistic_data_analysis.trip_data_05_2024_pr`
UNION ALL
SELECT * FROM `cyclistic_data_analysis.trip_data_06_2024_pr`
;


-- ###############################################################
-- # SECTION 2: Data Aggregation for Key Findings (Corresponding to PPT Slides)
-- # Purpose: Generate the summarized data for each visualization and insight
-- #          presented in the PowerPoint report. All queries in this section
-- #          use `cyclistic_data_analysis.all_merged_trip_data_pr`
-- #          as their primary source table, with necessary in-query filtering.
-- ###############################################################

-- 2.1 Average Ride Length by Member Type (for PPT Slide 5)
-- This query calculates the average ride length (in seconds and minutes) for both casual and member riders.
-- This data directly supports the comparison of typical ride durations between the two user segments.
-- Corresponds to data used in `average_ride_lengths.csv`. 
SELECT
    member_casual,
    AVG(ride_length_seconds) AS average_ride_length_seconds,
    AVG(ride_length_minutes) AS average_ride_length_minutes
FROM
    `cyclistic_data_analysis.all_merged_trip_data_pr`
-- No WHERE clause here, as filtering is handled in the `_pr` table creation 
GROUP BY
    member_casual
ORDER BY
    member_casual;


-- 2.2 Total Rides by Day of Week and Member Type (for PPT Slide 6)
-- This query counts the total number of rides for each day of the week, segmented by rider type.
-- It also includes average ride length by day and member type.
-- Results are ordered chronologically by day to facilitate consistent visualization of weekly patterns.
-- Corresponds to data used in `rides_by_day.csv` or `vary_usage_by_day.csv`. 
SELECT
    member_casual,
    day_of_week_name,
    COUNT(ride_id) AS total_rides,
    AVG(ride_length_minutes) AS average_ride_length_minutes -- Added as per your file 
FROM
    `cyclistic_data_analysis.all_merged_trip_data_pr`
-- No WHERE clause here, as filtering is handled in the `_pr` table creation 
GROUP BY
    member_casual,
    day_of_week_name
ORDER BY
    member_casual,
    -- Order by day number to get chronological order (e.g., Sunday-Saturday) as in your file 
    CASE
        WHEN day_of_week_name = 'Sunday' THEN 0
        WHEN day_of_week_name = 'Monday' THEN 1
        WHEN day_of_week_name = 'Tuesday' THEN 2
        WHEN day_of_week_name = 'Wednesday' THEN 3
        WHEN day_of_week_name = 'Thursday' THEN 4
        WHEN day_of_week_name = 'Friday' THEN 5
        WHEN day_of_week_name = 'Saturday' THEN 6
    END;


-- 2.3 Total Rides by Hour of Day and Member Type (for PPT Slide 7)
-- This query counts the total number of rides for each hour of the day (0-23), segmented by rider type.
-- This helps identify peak usage hours for casual vs. member riders.
-- Corresponds to data used in `rides_per_hour.csv`. 
SELECT
    member_casual,
    start_hour_of_day,
    COUNT(ride_id) AS total_rides
FROM
    `cyclistic_data_analysis.all_merged_trip_data_pr`
-- No WHERE clause here, as filtering is handled in the `_pr` table creation 
GROUP BY
    member_casual,
    start_hour_of_day
ORDER BY
    member_casual,
    start_hour_of_day;


-- 2.4 Top 10 Casual End Stations (for PPT Slide 8 - Casual Hotspots)
-- This query identifies the top 10 most popular end stations specifically for casual riders,
-- based on the total count of rides ending at each station. These stations often indicate leisure destinations.
-- Corresponds to data used in `top_casual_end_stations.csv`.
SELECT
    end_station_name,
    COUNT(ride_id) AS total_ends
FROM
    `cyclistic_data_analysis.all_merged_trip_data_pr`
WHERE
    member_casual = 'casual' AND end_station_name IS NOT NULL -- Filtering specific to casuals and non-null station names
GROUP BY
    end_station_name
ORDER BY
    total_ends DESC
LIMIT 10;


-- 2.5 Top 10 Member End Stations (for comparison or potential inclusion in PPT Slide 8)
-- This query identifies the top 10 most popular end stations specifically for member riders.
-- These stations often indicate commuting or frequent use points.
-- Corresponds to data used in `top_member_end_stations.csv`. 
SELECT
    end_station_name,
    COUNT(ride_id) AS total_ends
FROM
    `cyclistic_data_analysis.all_merged_trip_data_pr`
WHERE
    member_casual = 'member' AND end_station_name IS NOT NULL -- Filtering specific to members and non-null station names 
GROUP BY
    end_station_name
ORDER BY
    total_ends DESC
LIMIT 10;


-- 2.6 Top 10 Casual Start Stations (for comparison or potential inclusion in PPT Slide 8)
-- This query identifies the top 10 most popular start stations specifically for casual riders.
-- Often paired with end stations to understand common leisure routes.
-- Corresponds to data used in `top_casual_start_stations.csv`.
SELECT
    start_station_name,
    COUNT(ride_id) AS total_starts
FROM
    `cyclistic_data_analysis.all_merged_trip_data_pr`
WHERE
    member_casual = 'casual' AND start_station_name IS NOT NULL -- Filtering specific to casuals and non-null station names
GROUP BY
    start_station_name
ORDER BY
    total_starts DESC
LIMIT 10;


-- 2.7 Top 10 Member Start Stations (for comparison or potential inclusion in PPT Slide 8)
-- This query identifies the top 10 most popular start stations specifically for member riders.
-- Often indicates common commuting origins.
-- Corresponds to data used in `top_member_start_stations.csv`.
SELECT
    start_station_name,
    COUNT(ride_id) AS total_starts
FROM
    `cyclistic_data_analysis.all_merged_trip_data_pr`
WHERE
    member_casual = 'member' AND start_station_name IS NOT NULL -- Filtering specific to members and non-null station names
GROUP BY
    start_station_name
ORDER BY
    total_starts DESC
LIMIT 10;


-- 2.8 Total Rides by Rideable Type and Member Type (for 'popular_rideable_types.csv' / 'fav_rides.csv')
-- This query counts the total rides for each bike type (e.g., classic_bike, electric_bike),
-- segmented by casual and member riders. It reveals preferences for bike models. 
SELECT
    rideable_type,
    member_casual,
    COUNT(ride_id) AS total_rides
FROM
    `cyclistic_data_analysis.all_merged_trip_data_pr`
-- No WHERE clause here, as filtering is handled in the `_pr` table creation 
GROUP BY
    rideable_type,
    member_casual
ORDER BY
    member_casual, total_rides DESC;


-- 2.9 Overall Total Rides by Member Type (for 'total_rides_by_member_type.csv' / 'casual_vs_members.csv')
-- This query provides the high-level breakdown of the total number of rides
-- attributed to casual vs. annual members across the entire dataset, offering an overall usage ratio.
SELECT
    member_casual,
    COUNT(ride_id) AS total_rides
FROM
    `cyclistic_data_analysis.all_merged_trip_data_pr`
-- No WHERE clause here, as filtering is handled in the `_pr` table creation
GROUP BY
    member_casual
ORDER BY
    total_rides DESC;


-- ###############################################################
-- # END OF SQL QUERIES
-- ###############################################################
