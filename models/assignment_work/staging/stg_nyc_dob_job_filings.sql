-- Clean and standardize DOB NOW job filing data
-- One row per job filing (job_filing_number)
WITH source AS (
    SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),
cleaned AS (
    SELECT
        -- Pass through everything we are not transforming below
        * EXCEPT (
            job_filing_number,
            filing_status,
            borough,
            zip,
            postcode,
            council_district,
            commmunity_board,
            latitude,
            longitude,
            initial_cost,
            existing_dwelling_units,
            proposed_dwelling_units,
            filing_date,
            current_status_date,
            first_permit_date,
            approved_date,
            signoff_date
        ),
        -- Identifiers
        CAST(job_filing_number AS STRING) AS job_filing_number,
        UPPER(TRIM(CAST(filing_status AS STRING))) AS filing_status,
        -- Location: standardized borough (same logic as the 311 model)
        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN or CITYWIDE'
        END AS borough,
        -- Job-site ZIP (postcode) renamed to zip so it conforms with the 311 data
        CASE
            WHEN REGEXP_CONTAINS(TRIM(CAST(postcode AS STRING)), r'^\d{5}') THEN SUBSTR(TRIM(CAST(postcode AS STRING)), 1, 5)
            ELSE NULL
        END AS zip,
        -- The raw "zip" column is the APPLICANT's ZIP, so keep it separate
        CAST(zip AS STRING) AS applicant_zip,
        NULLIF(TRIM(CAST(council_district AS STRING)), '') AS council_district,
        CAST(commmunity_board AS STRING) AS community_board,
        SAFE_CAST(latitude AS DECIMAL) AS latitude,
        SAFE_CAST(longitude AS DECIMAL) AS longitude,
        -- Numbers
        SAFE_CAST(REGEXP_REPLACE(CAST(initial_cost AS STRING), r'[^0-9.]', '') AS NUMERIC) AS initial_cost,
        SAFE_CAST(existing_dwelling_units AS INT64) AS existing_dwelling_units,
        SAFE_CAST(proposed_dwelling_units AS INT64) AS proposed_dwelling_units,
        -- Dates
        SAFE_CAST(filing_date AS TIMESTAMP) AS filing_date,
        SAFE_CAST(current_status_date AS TIMESTAMP) AS current_status_date,
        SAFE_CAST(first_permit_date AS TIMESTAMP) AS first_permit_date,
        SAFE_CAST(approved_date AS TIMESTAMP) AS approved_date,
        SAFE_CAST(signoff_date AS TIMESTAMP) AS signoff_date,
        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at
    FROM source
    WHERE job_filing_number IS NOT NULL
      AND filing_date IS NOT NULL
    -- Deduplicate: keep the latest row per filing
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY job_filing_number
        ORDER BY current_status_date DESC
    ) = 1
)
SELECT * FROM cleaned