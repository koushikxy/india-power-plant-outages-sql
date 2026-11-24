USE power_outages;

LOAD DATA LOCAL INFILE 'data/clean/outage_rows.csv' INTO TABLE stg_outage
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

LOAD DATA LOCAL INFILE 'data/clean/unit_master.csv' INTO TABLE stg_unit
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

UPDATE stg_outage
SET state = TRIM(state),
    station = UPPER(TRIM(station)),
    unit_no = TRIM(unit_no),
    reason = UPPER(TRIM(reason));

UPDATE stg_unit
SET state = TRIM(state),
    station = UPPER(TRIM(station)),
    unit_no = TRIM(unit_no);

UPDATE stg_outage o
JOIN (SELECT DISTINCT station FROM stg_unit) u ON REPLACE(o.station, ' ', '') = REPLACE(u.station, ' ', '')
SET o.station = u.station
WHERE o.station <> u.station;

UPDATE stg_outage SET state = 'Chhattisgarh' WHERE state = 'Chhatisgarh';
UPDATE stg_unit SET state = 'Chhattisgarh' WHERE state = 'Chhatisgarh';

INSERT INTO states (state_name, region)
SELECT state, MAX(region)
FROM (
    SELECT state, region FROM stg_unit
    UNION
    SELECT state, region FROM stg_outage
) s
GROUP BY state;

INSERT INTO stations (station_name, state_id, sector, fuel_type)
SELECT x.station, st.state_id, x.sector, x.fuel_type
FROM (
    SELECT station,
           SUBSTRING_INDEX(GROUP_CONCAT(state ORDER BY file_date DESC), ',', 1) AS state,
           SUBSTRING_INDEX(GROUP_CONCAT(sector ORDER BY file_date DESC), ',', 1) AS sector,
           CASE WHEN MAX(fuel_type) = 'NUCLEAR' THEN 'Nuclear' ELSE 'Thermal' END AS fuel_type
    FROM stg_unit
    GROUP BY station
) x
JOIN states st ON st.state_name = x.state;

INSERT INTO stations (station_name, state_id, sector, fuel_type)
SELECT o.station, st.state_id, 'Unknown', 'Thermal'
FROM (SELECT station, MAX(state) AS state FROM stg_outage GROUP BY station) o
JOIN states st ON st.state_name = o.state
WHERE o.station NOT IN (SELECT station_name FROM stations);

INSERT INTO units (station_id, unit_no, capacity_mw, in_master)
SELECT s.station_id, u.unit_no,
       SUBSTRING_INDEX(GROUP_CONCAT(u.capacity_mw ORDER BY u.file_date DESC), ',', 1), 1
FROM stg_unit u
JOIN stations s ON s.station_name = u.station
GROUP BY s.station_id, u.unit_no;

INSERT INTO units (station_id, unit_no, capacity_mw, in_master)
SELECT s.station_id, o.unit_no,
       MAX(o.planned_mw + o.forced_major_mw + o.forced_minor_mw + o.other_mw), 0
FROM stg_outage o
JOIN stations s ON s.station_name = o.station
LEFT JOIN units u ON u.station_id = s.station_id AND u.unit_no = o.unit_no
WHERE u.unit_id IS NULL
GROUP BY s.station_id, o.unit_no;

INSERT INTO reasons (reason_text, category)
SELECT r,
       CASE
           WHEN r = '' THEN 'Not given'
           WHEN r LIKE '%SCRAP%' OR r LIKE '%VINTAGE%' OR r LIKE '%WITHDRAWN%' OR r LIKE '%DECOMMISSION%'
               THEN 'Retired or awaiting scrap'
           WHEN r LIKE '%PURCHASE AGREEMENT%' OR r LIKE '%RESERVE SHUT%' OR r LIKE '%RSD%'
                OR r LIKE '%LOW SCHEDULE%' OR r LIKE '%LOW SYSTEM DEMAND%' OR r LIKE '%COMMERCIAL%'
                OR r LIKE '%NO SCHEDULE%' OR r LIKE '%LOW DEMAND%' OR r LIKE '%IRRIGATION DEMAND%'
               THEN 'No demand or no buyer'
           WHEN r LIKE '%SHORTAGE%' OR r LIKE '%COAL QUALITY%' OR r LIKE '%POOR QUALITY%' OR r LIKE '%WET%COAL%'
                OR r LIKE '%COAL TRANSPORT%' OR r LIKE '%WATER NON AVAIL%' OR r LIKE '%FUEL SUPPLY%'
               THEN 'Fuel or water shortage'
           WHEN r LIKE '%ANNUAL MAINT%' OR r LIKE '%OVERHAUL%' OR r LIKE '%CAPITAL MAINT%' OR r LIKE '%PLANNED%'
                OR r LIKE '%RENOVATION%' OR r LIKE '%MODERNI%' OR r LIKE '%INSPECTION%' OR r LIKE '%REFUELLING%'
                OR r LIKE '%REACTOR MAINT%' OR r LIKE '%COOLANT CHANNEL%' OR r LIKE '%R&M%'
               THEN 'Planned maintenance'
           WHEN r LIKE '%TUBE L%' THEN 'Tube leakage'
           ELSE 'Other equipment fault'
       END
FROM (SELECT DISTINCT reason AS r FROM stg_outage) d;

INSERT IGNORE INTO outage_reports
    (report_date, unit_id, planned_mw, forced_major_mw, forced_minor_mw, other_mw,
     outage_start, expected_return, reason_id)
SELECT STR_TO_DATE(o.report_date, '%Y-%m-%d'), u.unit_id,
       o.planned_mw, o.forced_major_mw, o.forced_minor_mw, o.other_mw,
       STR_TO_DATE(NULLIF(o.outage_start, ''), '%Y-%m-%d %H:%i'),
       STR_TO_DATE(NULLIF(o.expected_return, ''), '%Y-%m-%d %H:%i'),
       r.reason_id
FROM stg_outage o
JOIN stations s ON s.station_name = o.station
JOIN units u ON u.station_id = s.station_id AND u.unit_no = o.unit_no
JOIN reasons r ON r.reason_text = o.reason
WHERE o.outage_start <> '';

SELECT
    (SELECT COUNT(*) FROM stg_outage) AS staged_rows,
    (SELECT COUNT(*) FROM stg_outage WHERE outage_start = '') AS rows_without_start,
    (SELECT COUNT(*) FROM outage_reports) AS loaded_rows,
    (SELECT COUNT(*) FROM states) AS states,
    (SELECT COUNT(*) FROM stations) AS stations,
    (SELECT COUNT(*) FROM units) AS units,
    (SELECT COUNT(*) FROM units WHERE in_master = 0) AS units_not_in_master,
    (SELECT COUNT(*) FROM reasons) AS reasons;
