-- Fact table for motor vehicle collisions
-- Grain: one row per collision (collision_id)
-- Each crash points to the PRIMARY factor and vehicle type (position 1)

WITH stg_mv AS (
    SELECT * FROM {{ ref('stg_mv_collisions') }}
),

fact_collision AS (
    SELECT
        collision_id,

        -- Foreign keys: built the same way as in each dimension
        CASE
            WHEN crash_date IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['crash_date']) }}
        END AS date_key,

        CASE
            WHEN borough IS NULL AND zip IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['borough', 'zip']) }}
        END AS location_key,

        CASE
            WHEN contributing_factor_vehicle_1 IS NULL
                OR TRIM(contributing_factor_vehicle_1) = '' THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['TRIM(contributing_factor_vehicle_1)']) }}
        END AS contri_factor_key,

        CASE
            WHEN vehicle_type_code1 IS NULL
                OR TRIM(vehicle_type_code1) = '' THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['UPPER(TRIM(vehicle_type_code1))']) }}
        END AS vehicle_type_key,

        -- Descriptive columns kept on the fact
        crash_time,
        latitude,
        longitude,
        on_street_name,
        off_street_name,
        cross_street_name,

        -- Measures
        COALESCE(number_of_persons_injured, 0) AS number_of_persons_injured,
        COALESCE(number_of_persons_killed, 0) AS number_of_persons_killed,
        COALESCE(number_of_pedestrians_injured, 0) AS number_of_pedestrians_injured,
        COALESCE(number_of_pedestrians_killed, 0) AS number_of_pedestrians_killed,
        COALESCE(number_of_cyclist_injured, 0) AS number_of_cyclist_injured,
        COALESCE(number_of_cyclist_killed, 0) AS number_of_cyclist_killed,
        COALESCE(number_of_motorist_injured, 0) AS number_of_motorist_injured,
        COALESCE(number_of_motorist_killed, 0) AS number_of_motorist_killed
    FROM stg_mv
)

SELECT * FROM fact_collision