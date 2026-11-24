USE power_outages;

CREATE OR REPLACE VIEW v_outage_days AS
SELECT o.report_id, o.report_date, o.outage_start, o.expected_return,
       CASE WHEN MONTH(o.report_date) >= 4
            THEN CONCAT(YEAR(o.report_date), '-', RIGHT(YEAR(o.report_date) + 1, 2))
            ELSE CONCAT(YEAR(o.report_date) - 1, '-', RIGHT(YEAR(o.report_date), 2)) END AS fiscal_year,
       o.planned_mw, o.forced_major_mw + o.forced_minor_mw AS forced_mw, o.other_mw,
       o.planned_mw + o.forced_major_mw + o.forced_minor_mw + o.other_mw AS total_mw,
       CASE WHEN r.category IN ('Tube leakage', 'Other equipment fault')
            THEN o.planned_mw + o.forced_major_mw + o.forced_minor_mw + o.other_mw ELSE 0 END AS breakdown_mw,
       u.unit_id, u.unit_no, u.capacity_mw, s.station_id, s.station_name, s.sector, s.fuel_type,
       st.state_name, st.region, r.reason_text, r.category
FROM outage_reports o
JOIN units u ON u.unit_id = o.unit_id
JOIN stations s ON s.station_id = u.station_id
JOIN states st ON st.state_id = s.state_id
JOIN reasons r ON r.reason_id = o.reason_id;

DROP TABLE IF EXISTS outage_events;

CREATE TABLE outage_events (PRIMARY KEY (unit_id, outage_start))
SELECT unit_id, outage_start, report_date AS first_report, last_report, days_reported, mw_out,
       category, reason_text
FROM (
    SELECT unit_id, outage_start, report_date, category, reason_text,
           ROW_NUMBER() OVER (PARTITION BY unit_id, outage_start ORDER BY report_date) AS rn,
           COUNT(*) OVER (PARTITION BY unit_id, outage_start) AS days_reported,
           MAX(report_date) OVER (PARTITION BY unit_id, outage_start) AS last_report,
           MAX(total_mw) OVER (PARTITION BY unit_id, outage_start) AS mw_out
    FROM v_outage_days
) numbered
WHERE rn = 1;


SELECT COUNT(DISTINCT report_date) AS days,
       COUNT(*) AS report_rows,
       COUNT(DISTINCT unit_id) AS units_seen,
       COUNT(DISTINCT station_id) AS stations_seen,
       (SELECT COUNT(*) FROM outage_events) AS outage_events,
       (SELECT ROUND(SUM(capacity_mw)) FROM units WHERE in_master = 1) AS master_capacity_mw
FROM v_outage_days;


SELECT fiscal_year,
       COUNT(DISTINCT report_date) AS days,
       ROUND(SUM(total_mw) / COUNT(DISTINCT report_date)) AS avg_mw_out,
       ROUND(SUM(planned_mw) / COUNT(DISTINCT report_date)) AS avg_planned_mw,
       ROUND(SUM(forced_mw) / COUNT(DISTINCT report_date)) AS avg_forced_mw,
       ROUND(SUM(other_mw) / COUNT(DISTINCT report_date)) AS avg_other_mw,
       ROUND(SUM(breakdown_mw) / COUNT(DISTINCT report_date)) AS avg_breakdown_mw,
       ROUND(SUM(CASE WHEN station_name <> 'MUNDRA UMTPP' THEN breakdown_mw ELSE 0 END)
             / COUNT(DISTINCT report_date)) AS avg_breakdown_ex_mundra_mw
FROM v_outage_days
GROUP BY fiscal_year
ORDER BY fiscal_year;


SELECT category,
       ROUND(SUM(total_mw) / (SELECT COUNT(DISTINCT report_date) FROM outage_reports)) AS avg_mw_out,
       ROUND(100 * SUM(total_mw) / SUM(SUM(total_mw)) OVER (), 1) AS pct_of_mw_out,
       COUNT(DISTINCT unit_id) AS units
FROM v_outage_days
GROUP BY category
ORDER BY avg_mw_out DESC;


WITH monthly AS (
    SELECT DATE_FORMAT(report_date, '%Y-%m') AS month,
           SUM(total_mw) / COUNT(DISTINCT report_date) AS avg_mw_out,
           SUM(CASE WHEN category = 'No demand or no buyer' THEN total_mw ELSE 0 END)
               / COUNT(DISTINCT report_date) AS avg_no_demand_mw
    FROM v_outage_days
    GROUP BY DATE_FORMAT(report_date, '%Y-%m')
)
SELECT month,
       ROUND(avg_mw_out) AS avg_mw_out,
       ROUND(avg_no_demand_mw) AS avg_no_demand_mw,
       ROUND(LAG(avg_mw_out, 12) OVER (ORDER BY month)) AS same_month_last_year,
       ROUND(100 * (avg_mw_out / LAG(avg_mw_out, 12) OVER (ORDER BY month) - 1), 1) AS yoy_pct
FROM monthly
ORDER BY month;


SELECT reason_text,
       COUNT(*) AS events,
       ROUND(AVG(days_reported), 1) AS avg_days_listed
FROM outage_events
WHERE outage_start >= '2023-04-01'
  AND category IN ('Tube leakage', 'Other equipment fault')
GROUP BY reason_text
ORDER BY events DESC
LIMIT 10;


SELECT CASE
           WHEN days_reported = 1 THEN 'a. 1 report'
           WHEN days_reported <= 3 THEN 'b. 2-3 reports'
           WHEN days_reported <= 7 THEN 'c. 4-7 reports'
           WHEN days_reported <= 30 THEN 'd. 8-30 reports'
           ELSE 'e. over 30 reports'
       END AS days_listed,
       COUNT(*) AS events,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct,
       ROUND(100 * SUM(COUNT(*)) OVER (ORDER BY MIN(days_reported)) / SUM(COUNT(*)) OVER (), 1) AS cumulative_pct
FROM outage_events
WHERE outage_start >= '2023-04-01'
  AND last_report < '2026-03-31'
  AND category IN ('Tube leakage', 'Other equipment fault')
GROUP BY days_listed
ORDER BY days_listed;


SELECT s.station_name, st.state_name, u.unit_no, u.capacity_mw,
       COUNT(*) AS days_listed, MIN(o.outage_start) AS out_since, MAX(r.reason_text) AS reason
FROM outage_reports o
JOIN units u ON u.unit_id = o.unit_id
JOIN stations s ON s.station_id = u.station_id
JOIN states st ON st.state_id = s.state_id
JOIN reasons r ON r.reason_id = o.reason_id
GROUP BY s.station_name, st.state_name, u.unit_no, u.capacity_mw
HAVING COUNT(*) >= 0.9 * (SELECT COUNT(DISTINCT report_date) FROM outage_reports)
ORDER BY u.capacity_mw DESC;


WITH fleet AS (
    SELECT s.sector, SUM(u.capacity_mw) AS capacity_mw, COUNT(*) AS units
    FROM units u
    JOIN stations s ON s.station_id = u.station_id
    WHERE u.in_master = 1 AND u.capacity_mw > 0 AND s.fuel_type = 'Thermal'
    GROUP BY s.sector
),
lost AS (
    SELECT sector,
           SUM(breakdown_mw) AS breakdown_mw_days,
           SUM(CASE WHEN category = 'No demand or no buyer' THEN total_mw ELSE 0 END) AS no_demand_mw_days
    FROM v_outage_days
    WHERE fuel_type = 'Thermal'
    GROUP BY sector
)
SELECT f.sector, f.units, ROUND(f.capacity_mw) AS capacity_mw,
       ROUND(100 * l.breakdown_mw_days / (f.capacity_mw * (SELECT COUNT(DISTINCT report_date) FROM outage_reports)), 1)
           AS breakdown_pct,
       ROUND(100 * l.no_demand_mw_days / (f.capacity_mw * (SELECT COUNT(DISTINCT report_date) FROM outage_reports)), 1)
           AS no_demand_pct
FROM fleet f
JOIN lost l ON l.sector = f.sector
ORDER BY breakdown_pct DESC;


WITH state_fleet AS (
    SELECT s.state_id, SUM(u.capacity_mw) AS capacity_mw,
           SUM(CASE WHEN s.station_name <> 'MUNDRA UMTPP' THEN u.capacity_mw ELSE 0 END) AS capacity_ex_mundra_mw
    FROM units u
    JOIN stations s ON s.station_id = u.station_id
    WHERE u.in_master = 1 AND u.capacity_mw > 0 AND s.fuel_type = 'Thermal'
    GROUP BY s.state_id
),
state_breakdown AS (
    SELECT st.state_name, st.region, sf.capacity_mw,
           100 * SUM(v.breakdown_mw) / (sf.capacity_mw * (SELECT COUNT(DISTINCT report_date) FROM outage_reports))
               AS breakdown_pct,
           100 * SUM(CASE WHEN v.station_name <> 'MUNDRA UMTPP' THEN v.breakdown_mw ELSE 0 END)
               / (sf.capacity_ex_mundra_mw * (SELECT COUNT(DISTINCT report_date) FROM outage_reports))
               AS breakdown_ex_mundra_pct
    FROM v_outage_days v
    JOIN states st ON st.state_name = v.state_name
    JOIN state_fleet sf ON sf.state_id = st.state_id
    WHERE v.fuel_type = 'Thermal'
    GROUP BY st.state_name, st.region, sf.capacity_mw, sf.capacity_ex_mundra_mw
    HAVING sf.capacity_mw >= 2000
)
SELECT region, state_name, ROUND(capacity_mw) AS capacity_mw, ROUND(breakdown_pct, 1) AS breakdown_pct,
       ROUND(breakdown_ex_mundra_pct, 1) AS breakdown_ex_mundra_pct,
       RANK() OVER (ORDER BY breakdown_pct DESC) AS india_rank,
       ROW_NUMBER() OVER (PARTITION BY region ORDER BY breakdown_pct DESC) AS rank_in_region
FROM state_breakdown
ORDER BY india_rank;


WITH fy_days AS (
    SELECT fiscal_year, COUNT(DISTINCT report_date) AS days
    FROM v_outage_days
    GROUP BY fiscal_year
),
by_year AS (
    SELECT v.state_name, v.fiscal_year, SUM(v.breakdown_mw) / MAX(d.days) AS avg_breakdown_mw
    FROM v_outage_days v
    JOIN fy_days d ON d.fiscal_year = v.fiscal_year
    GROUP BY v.state_name, v.fiscal_year
),
top_states AS (
    SELECT state_name FROM v_outage_days GROUP BY state_name ORDER BY SUM(breakdown_mw) DESC LIMIT 6
)
SELECT b.state_name, b.fiscal_year, ROUND(b.avg_breakdown_mw) AS avg_breakdown_mw,
       ROUND(b.avg_breakdown_mw - LAG(b.avg_breakdown_mw) OVER (PARTITION BY b.state_name ORDER BY b.fiscal_year))
           AS change_vs_last_year
FROM by_year b
JOIN top_states t ON t.state_name = b.state_name
ORDER BY b.state_name, b.fiscal_year;


WITH station_loss AS (
    SELECT station_name, state_name, SUM(breakdown_mw) AS breakdown_mw_days
    FROM v_outage_days
    GROUP BY station_name, state_name
    HAVING SUM(breakdown_mw) > 0
),
ranked AS (
    SELECT station_name, state_name, breakdown_mw_days,
           ROW_NUMBER() OVER (ORDER BY breakdown_mw_days DESC) AS rn,
           SUM(breakdown_mw_days) OVER (ORDER BY breakdown_mw_days DESC ROWS UNBOUNDED PRECEDING)
               / SUM(breakdown_mw_days) OVER () AS cumulative_share
    FROM station_loss
)
SELECT rn, station_name, state_name, ROUND(breakdown_mw_days) AS breakdown_mw_days,
       ROUND(100 * cumulative_share, 1) AS cumulative_pct
FROM ranked
WHERE rn <= 15 OR rn = (SELECT MIN(rn) FROM ranked WHERE cumulative_share >= 0.5)
ORDER BY rn;


WITH unit_trips AS (
    SELECT e.unit_id, COUNT(*) AS breakdowns
    FROM outage_events e
    WHERE e.outage_start >= '2023-04-01'
      AND e.category IN ('Tube leakage', 'Other equipment fault')
    GROUP BY e.unit_id
)
SELECT s.station_name, st.state_name, s.sector, u.unit_no, u.capacity_mw, t.breakdowns
FROM unit_trips t
JOIN units u ON u.unit_id = t.unit_id
JOIN stations s ON s.station_id = u.station_id
JOIN states st ON st.state_id = s.state_id
WHERE t.breakdowns > (
    SELECT AVG(t2.breakdowns)
    FROM unit_trips t2
    JOIN units u2 ON u2.unit_id = t2.unit_id
    JOIN stations s2 ON s2.station_id = u2.station_id
    WHERE s2.sector = s.sector
) * 3
ORDER BY t.breakdowns DESC
LIMIT 15;


SELECT CASE WHEN u.capacity_mw < 250 THEN 'a. under 250 MW'
            WHEN u.capacity_mw < 500 THEN 'b. 250-499 MW'
            WHEN u.capacity_mw < 660 THEN 'c. 500-659 MW'
            ELSE 'd. 660 MW and above' END AS unit_size,
       COUNT(DISTINCT u.unit_id) AS units,
       ROUND(SUM(e.breakdowns) / COUNT(DISTINCT u.unit_id), 1) AS breakdowns_per_unit
FROM units u
JOIN stations s ON s.station_id = u.station_id
LEFT JOIN (
    SELECT unit_id, COUNT(*) AS breakdowns
    FROM outage_events
    WHERE outage_start >= '2023-04-01'
      AND category IN ('Tube leakage', 'Other equipment fault')
    GROUP BY unit_id
) e ON e.unit_id = u.unit_id
WHERE u.in_master = 1 AND u.capacity_mw > 0 AND s.fuel_type = 'Thermal'
GROUP BY unit_size
ORDER BY unit_size;


SELECT HOUR(outage_start) AS start_hour,
       COUNT(*) AS breakdowns,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM outage_events
WHERE outage_start >= '2023-04-01'
  AND category IN ('Tube leakage', 'Other equipment fault')
GROUP BY HOUR(outage_start)
ORDER BY start_hour;


SELECT fiscal_year,
       ROUND(SUM(planned_mw) / COUNT(DISTINCT report_date), 1) AS in_planned_mw,
       ROUND(SUM(forced_mw) / COUNT(DISTINCT report_date), 1) AS in_forced_mw,
       ROUND(SUM(other_mw) / COUNT(DISTINCT report_date), 1) AS in_others_mw,
       ROUND(SUM(total_mw) / COUNT(DISTINCT report_date), 1) AS total_no_demand_mw
FROM v_outage_days
WHERE category = 'No demand or no buyer'
GROUP BY fiscal_year
ORDER BY fiscal_year;


SELECT CASE WHEN report_date < '2025-04-15' THEN 'a. before 15 Apr 2025' ELSE 'b. from 15 Apr 2025' END AS layout,
       ROUND(100 * SUM(forced_mw) / SUM(total_mw), 1) AS pct_in_forced,
       ROUND(100 * SUM(other_mw) / SUM(total_mw), 1) AS pct_in_others
FROM v_outage_days
WHERE category = 'No demand or no buyer'
GROUP BY layout
ORDER BY layout;


SELECT e.unit_id, u.unit_no, u.capacity_mw, e.outage_start, e.last_report, e.days_reported, e.reason_text
FROM outage_events e
JOIN units u ON u.unit_id = e.unit_id
JOIN stations s ON s.station_id = u.station_id
WHERE s.station_name = 'MUNDRA UMTPP' AND e.days_reported >= 100
ORDER BY e.outage_start;


SELECT SUM(MINUTE(outage_start) = 0) AS exactly_midnight,
       COUNT(*) AS hour_zero_starts
FROM outage_events
WHERE outage_start >= '2023-04-01'
  AND category IN ('Tube leakage', 'Other equipment fault')
  AND HOUR(outage_start) = 0;
