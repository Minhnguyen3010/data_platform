-- Airbyte HRM.Employee lab
-- Run one labeled block at a time in the matching client.
-- Do not run the whole file: sync with Airbyte between change blocks.

-- ============================================================
-- MYSQL — setup and seed (run once in MySQL Workbench as root)
-- ============================================================
CREATE DATABASE IF NOT EXISTS HRM;

USE HRM;

CREATE TABLE IF NOT EXISTS Employee (
    EmployeeID int NOT NULL,
    FirstName varchar(80) NOT NULL,
    LastName varchar(80) NOT NULL,
    Email varchar(255) NOT NULL,
    Department varchar(100) NOT NULL,
    Salary decimal(12, 2) NOT NULL,
    UpdatedAt datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
        ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (EmployeeID),
    UNIQUE KEY uq_employee_email (Email)
) ENGINE = InnoDB;

GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT
ON *.* TO 'data_platform'@'%';

INSERT IGNORE INTO Employee (
    EmployeeID, FirstName, LastName, Email, Department, Salary
)
VALUES
    (101, 'An', 'Nguyen', 'an.nguyen@example.test', 'Engineering', 72000.00),
    (102, 'Binh', 'Tran', 'binh.tran@example.test', 'Finance', 68000.00),
    (103, 'Chi', 'Le', 'chi.le@example.test', 'HR', 61000.00);

SELECT COUNT(*) AS source_employee_count FROM Employee;

-- ============================================================
-- MYSQL — phase 1: INSERT; run this block, then sync Airbyte
-- ============================================================
INSERT INTO Employee (
    EmployeeID, FirstName, LastName, Email, Department, Salary
)
VALUES (104, 'Dung', 'Pham', 'dung.pham@example.test', 'Operations', 59000.00);

SELECT COUNT(*) AS source_employee_count FROM Employee;

-- ============================================================
-- MYSQL — phase 2: UPDATE; run this block, then sync Airbyte
-- ============================================================
UPDATE Employee
SET Department = 'Data Engineering',
    Salary = 75000.00
WHERE EmployeeID = 102;

SELECT COUNT(*) AS source_employee_count FROM Employee;
SELECT * FROM Employee WHERE EmployeeID = 102;

-- ============================================================
-- MYSQL — phase 3: DELETE; run this block, then sync Airbyte
-- ============================================================
DELETE FROM Employee
WHERE EmployeeID = 103;

SELECT COUNT(*) AS source_employee_count FROM Employee;

-- ============================================================
-- POSTGRESQL — destination reconciliation
-- Run only in a PostgreSQL client after Airbyte creates the stream table.
-- Configure separate Airbyte namespaces: airbyte_hrm_full,
-- airbyte_hrm_append and airbyte_hrm_deduped.
-- ============================================================
SELECT
    COUNT(*) AS destination_event_rows,
    COUNT(*) FILTER (
        WHERE "_ab_cdc_deleted_at" IS NOT NULL
    ) AS cdc_delete_events
FROM airbyte_hrm_append."Employee";

SELECT
    "EmployeeID",
    "_ab_cdc_deleted_at"
FROM airbyte_hrm_append."Employee"
WHERE "EmployeeID" = 103
ORDER BY "_ab_cdc_deleted_at" NULLS FIRST;

-- Full Refresh and Append + Deduped are current-state comparisons.
SELECT COUNT(*) AS full_refresh_employee_count
FROM airbyte_hrm_full."Employee";

SELECT
    COUNT(*) AS deduped_employee_count,
    COUNT(*) FILTER (WHERE "EmployeeID" = 103) AS deleted_employee_still_present
FROM airbyte_hrm_deduped."Employee";
