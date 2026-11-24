DROP DATABASE IF EXISTS power_outages;
CREATE DATABASE power_outages;
USE power_outages;

CREATE TABLE states (
    state_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    state_name VARCHAR(40) NOT NULL UNIQUE,
    region VARCHAR(15) NOT NULL
);

CREATE TABLE stations (
    station_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    station_name VARCHAR(80) NOT NULL UNIQUE,
    state_id TINYINT UNSIGNED NOT NULL,
    sector VARCHAR(10) NOT NULL,
    fuel_type VARCHAR(10) NOT NULL,
    FOREIGN KEY (state_id) REFERENCES states (state_id)
);

CREATE TABLE units (
    unit_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    station_id SMALLINT UNSIGNED NOT NULL,
    unit_no VARCHAR(6) NOT NULL,
    capacity_mw DECIMAL(7, 2) NOT NULL,
    in_master TINYINT NOT NULL,
    UNIQUE KEY uq_unit (station_id, unit_no),
    FOREIGN KEY (station_id) REFERENCES stations (station_id)
);

CREATE TABLE reasons (
    reason_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    reason_text VARCHAR(150) NOT NULL UNIQUE,
    category VARCHAR(30) NOT NULL
);

CREATE TABLE outage_reports (
    report_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    report_date DATE NOT NULL,
    unit_id SMALLINT UNSIGNED NOT NULL,
    planned_mw DECIMAL(7, 2) NOT NULL,
    forced_major_mw DECIMAL(7, 2) NOT NULL,
    forced_minor_mw DECIMAL(7, 2) NOT NULL,
    other_mw DECIMAL(7, 2) NOT NULL,
    outage_start DATETIME NOT NULL,
    expected_return DATETIME NULL,
    reason_id SMALLINT UNSIGNED NOT NULL,
    UNIQUE KEY uq_report (unit_id, outage_start, report_date),
    FOREIGN KEY (unit_id) REFERENCES units (unit_id),
    FOREIGN KEY (reason_id) REFERENCES reasons (reason_id)
);

CREATE TABLE stg_outage (
    report_date VARCHAR(10),
    region VARCHAR(20),
    state VARCHAR(40),
    station VARCHAR(100),
    unit_no VARCHAR(10),
    planned_mw VARCHAR(12),
    forced_major_mw VARCHAR(12),
    forced_minor_mw VARCHAR(12),
    other_mw VARCHAR(12),
    outage_start VARCHAR(20),
    expected_return VARCHAR(20),
    reason VARCHAR(255)
);

CREATE TABLE stg_unit (
    file_date VARCHAR(10),
    region VARCHAR(20),
    state VARCHAR(40),
    sector VARCHAR(20),
    fuel_type VARCHAR(20),
    station VARCHAR(100),
    unit_no VARCHAR(10),
    capacity_mw VARCHAR(12)
);
