USE hospital_analytics;
GO

-- Q1a. Readmission rate by hospital and year (Northgate Community is getting worse)
SELECT h.hospital_name,
       YEAR(a.admit_date) AS yr,
       COUNT(*) AS admissions,
       CAST(100.0 * SUM(a.readmitted_30d) / COUNT(*) AS DECIMAL(5,1)) AS readmit_pct
FROM dbo.fact_admissions a
JOIN dbo.dim_hospital h ON h.hospital_id = a.hospital_id
GROUP BY h.hospital_name, YEAR(a.admit_date)
ORDER BY h.hospital_name, yr;

-- Q1b. Readmission rate by diagnosis (chronic conditions are readmitted most)
SELECT d.diagnosis,
       COUNT(*) AS admissions,
       CAST(100.0 * SUM(a.readmitted_30d) / COUNT(*) AS DECIMAL(4,1)) AS readmit_pct
FROM dbo.fact_admissions a
JOIN dbo.dim_diagnosis d ON d.diagnosis_id = a.diagnosis_id
GROUP BY d.diagnosis
ORDER BY readmit_pct DESC;

-- Q2. Winter surge: average monthly admissions in winter vs the rest of the year
WITH monthly AS (
    SELECT hospital_id,
           YEAR(admit_date)  AS yr,
           MONTH(admit_date) AS mth,
           COUNT(*)          AS admissions
    FROM dbo.fact_admissions
    GROUP BY hospital_id, YEAR(admit_date), MONTH(admit_date)
)
SELECT h.hospital_name,
       CAST(AVG(CASE WHEN m.mth IN (12, 1, 2) THEN 1.0 * m.admissions END) AS DECIMAL(8,1)) AS avg_winter,
       CAST(AVG(CASE WHEN m.mth NOT IN (12, 1, 2) THEN 1.0 * m.admissions END) AS DECIMAL(8,1)) AS avg_other,
       CAST(AVG(CASE WHEN m.mth IN (12, 1, 2) THEN 1.0 * m.admissions END)
          / AVG(CASE WHEN m.mth NOT IN (12, 1, 2) THEN 1.0 * m.admissions END) AS DECIMAL(4,2)) AS winter_ratio
FROM monthly m
JOIN dbo.dim_hospital h ON h.hospital_id = m.hospital_id
GROUP BY h.hospital_name
ORDER BY winter_ratio DESC;

-- Q3a. Cost and length of stay by diabetes control (HbA1c >= 8 = poor control)
WITH diabetic AS (
    SELECT a.admission_id,
           a.total_cost,
           a.length_of_stay,
           CASE WHEN l.value >= 8 THEN 'Poor control (HbA1c >= 8)'
                ELSE 'Good control (HbA1c < 8)' END AS control_group
    FROM dbo.fact_lab_results l
    JOIN dbo.fact_admissions a ON a.admission_id = l.admission_id
    WHERE l.test_name = 'hba1c'
)
SELECT control_group,
       COUNT(*) AS admissions,
       CAST(AVG(total_cost) AS DECIMAL(10,0)) AS avg_cost,
       CAST(AVG(1.0 * length_of_stay) AS DECIMAL(4,1)) AS avg_los_days
FROM diabetic
GROUP BY control_group;

-- Q3b. Where the money goes: cost by diagnosis
SELECT d.diagnosis,
       COUNT(*) AS admissions,
       CAST(AVG(a.total_cost) AS DECIMAL(10,0)) AS avg_cost,
       CAST(SUM(a.total_cost) / 1000000 AS DECIMAL(10,1)) AS total_cost_millions
FROM dbo.fact_admissions a
JOIN dbo.dim_diagnosis d ON d.diagnosis_id = a.diagnosis_id
GROUP BY d.diagnosis
ORDER BY total_cost_millions DESC;

-- Q3c. Emergency vs elective admissions
SELECT admission_type,
       COUNT(*) AS admissions,
       CAST(AVG(total_cost) AS DECIMAL(10,0)) AS avg_cost,
       CAST(AVG(1.0 * length_of_stay) AS DECIMAL(4,1)) AS avg_los_days,
       CAST(100.0 * SUM(readmitted_30d) / COUNT(*) AS DECIMAL(4,1)) AS readmit_pct
FROM dbo.fact_admissions
GROUP BY admission_type;

-- Q4a. Length of stay and readmissions by age group
WITH labelled AS (
    SELECT a.length_of_stay,
           a.readmitted_30d,
           CASE WHEN YEAR(a.admit_date) - p.birth_year < 18 THEN '1. Under 18'
                WHEN YEAR(a.admit_date) - p.birth_year < 40 THEN '2. 18-39'
                WHEN YEAR(a.admit_date) - p.birth_year < 65 THEN '3. 40-64'
                ELSE '4. 65+' END AS age_group
    FROM dbo.fact_admissions a
    JOIN dbo.dim_patient p ON p.patient_id = a.patient_id
)
SELECT age_group,
       COUNT(*) AS admissions,
       CAST(AVG(1.0 * length_of_stay) AS DECIMAL(4,1)) AS avg_los_days,
       CAST(100.0 * SUM(readmitted_30d) / COUNT(*) AS DECIMAL(4,1)) AS readmit_pct
FROM labelled
GROUP BY age_group
ORDER BY age_group;

-- Q4b. Length of stay and readmissions by number of chronic conditions (diabetes, hypertension)
SELECT p.has_diabetes + p.has_hypertension AS chronic_conditions,
       COUNT(*) AS admissions,
       CAST(AVG(1.0 * a.length_of_stay) AS DECIMAL(4,1)) AS avg_los_days,
       CAST(100.0 * SUM(a.readmitted_30d) / COUNT(*) AS DECIMAL(4,1)) AS readmit_pct
FROM dbo.fact_admissions a
JOIN dbo.dim_patient p ON p.patient_id = a.patient_id
GROUP BY p.has_diabetes + p.has_hypertension
ORDER BY chronic_conditions;