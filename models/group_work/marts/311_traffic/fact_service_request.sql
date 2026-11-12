-- Fact table for 311 traffic service requests
-- Grain: one row per service request (request_id)
-- No numeric measures: this is a factless fact table, analysed by counting requests

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_311_traffic') }}
),

-- Clean the dimension columns the same way each dimension does,
-- so the keys below match
cleaned AS (
    SELECT
        *,
        NULLIF(TRIM(agency), '') AS agency_clean,
        NULLIF(TRIM(complaint_type), '') AS complaint_type_clean,
        NULLIF(TRIM(descriptor), '') AS descriptor_clean,
        NULLIF(TRIM(descriptor_2), '') AS descriptor_2_clean,
        NULLIF(TRIM(resolution_description), '') AS resolution_clean,
        NULLIF(TRIM(status), '') AS status_clean,
        NULLIF(TRIM(community_board), '') AS community_board_clean,
        NULLIF(TRIM(CAST(council_district AS STRING)), '') AS council_district_clean,
        NULLIF(TRIM(police_precinct), '') AS police_precinct_clean,
        NULLIF(TRIM(bridge_highway_name), '') AS bridge_name_clean,
        NULLIF(TRIM(bridge_highway_direction), '') AS bridge_direction_clean,
        NULLIF(TRIM(road_ramp), '') AS road_ramp_clean,
        NULLIF(TRIM(bridge_highway_segment), '') AS bridge_segment_clean
    FROM stg_311
),

fact_service_request AS (
    SELECT
        request_id,

        -- Foreign keys: built the same way as in each dimension
        CASE
            WHEN created_date IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['DATE(created_date)']) }}
        END AS created_date_key,

        CASE
            WHEN closed_date IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['DATE(closed_date)']) }}
        END AS closed_date_key,

        CASE
            WHEN borough IS NULL AND zip IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['borough', 'zip']) }}
        END AS location_key,

        CASE
            WHEN agency_clean IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['agency_clean']) }}
        END AS agency_key,

        CASE
            WHEN complaint_type_clean IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['complaint_type_clean', 'descriptor_clean', 'descriptor_2_clean']) }}
        END AS complaint_key,

        CASE
            WHEN resolution_clean IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['resolution_clean']) }}
        END AS resolution_key,

        CASE
            WHEN community_board_clean IS NULL
                AND council_district_clean IS NULL
                AND police_precinct_clean IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['community_board_clean', 'council_district_clean', 'police_precinct_clean']) }}
        END AS local_gov_key,

        CASE
            WHEN bridge_name_clean IS NULL
                AND bridge_direction_clean IS NULL
                AND road_ramp_clean IS NULL
                AND bridge_segment_clean IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['bridge_name_clean', 'bridge_direction_clean', 'road_ramp_clean', 'bridge_segment_clean']) }}
        END AS bridge_key,

        CASE
            WHEN status_clean IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['status_clean']) }}
        END AS status_key,

        -- Descriptive columns kept on the fact
        resolution_action_updated_date,
        location_type,
        incident_address,
        street_name,
        cross_street_1,
        cross_street_2,
        intersection_street_1,
        intersection_street_2,
        address_type,
        city,
        landmark,
        bbl,
        method_of_submission,
        latitude,
        longitude
    FROM cleaned
)

SELECT * FROM fact_service_request