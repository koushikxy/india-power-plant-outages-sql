USE power_outages;

EXPLAIN
SELECT report_date, COUNT(*) AS units_out, SUM(forced_major_mw + forced_minor_mw) AS forced_mw
FROM outage_reports
WHERE report_date BETWEEN '2025-05-01' AND '2025-05-31'
GROUP BY report_date;

EXPLAIN ANALYZE
SELECT report_date, COUNT(*) AS units_out, SUM(forced_major_mw + forced_minor_mw) AS forced_mw
FROM outage_reports
WHERE report_date BETWEEN '2025-05-01' AND '2025-05-31'
GROUP BY report_date;

CREATE INDEX idx_report_date ON outage_reports (report_date);

EXPLAIN
SELECT report_date, COUNT(*) AS units_out, SUM(forced_major_mw + forced_minor_mw) AS forced_mw
FROM outage_reports
WHERE report_date BETWEEN '2025-05-01' AND '2025-05-31'
GROUP BY report_date;

EXPLAIN ANALYZE
SELECT report_date, COUNT(*) AS units_out, SUM(forced_major_mw + forced_minor_mw) AS forced_mw
FROM outage_reports
WHERE report_date BETWEEN '2025-05-01' AND '2025-05-31'
GROUP BY report_date;
