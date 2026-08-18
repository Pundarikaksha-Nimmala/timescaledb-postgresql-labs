-- ===========================================
-- Common Table Expressions (CTEs)
-- ===========================================

------------------------------------------------
-- Simple CTE
------------------------------------------------

WITH high_salary AS (
    SELECT *
    FROM employees
    WHERE salary > 100000
)
SELECT *
FROM high_salary;

------------------------------------------------
-- Multiple CTEs
------------------------------------------------

WITH dept_avg AS (
    SELECT
        department,
        AVG(salary) AS avg_salary
    FROM employees
    GROUP BY department
),
high_paid AS (
    SELECT *
    FROM employees
    WHERE salary > 100000
)
SELECT
    h.employee_name,
    h.salary,
    d.avg_salary
FROM high_paid h
JOIN dept_avg d
ON h.department = d.department;

------------------------------------------------
-- Recursive CTE
------------------------------------------------

WITH RECURSIVE numbers AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1
    FROM numbers
    WHERE n < 10
)
SELECT *
FROM numbers;
