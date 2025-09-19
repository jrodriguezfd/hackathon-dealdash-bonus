-- 1. TABLA CONSULTANT MASTER
CREATE OR REPLACE TABLE `jrodriguez-sandbox.hackathon_bonus_update.consultant_master` (
  consultant_id STRING,
  consultant_name STRING,
  plan_type STRING,                -- 'Sales', 'Hybrid', 'Delivery'
  eligible_for_comp BOOLEAN,
  active BOOLEAN
);

-- 2. TABLA DEALS REPORT (HUBSPOT DATA)
CREATE OR REPLACE TABLE `jrodriguez-sandbox.hackathon_bonus_update.deals_report` (
  deal_id STRING,
  consultant_id STRING,
  quarter INTEGER,
  year INTEGER,
  deal_name STRING,
  deal_amount FLOAT64,             -- Amount completo del deal
  close_date DATE,
  participation_type STRING,       -- 'Owner', 'Collaborator'
  is_recurring_business BOOLEAN,
  client_name STRING,
  channel STRING,                  -- 'Google', etc.
  deal_type STRING                 -- 'PS', 'Cloud Consumption'
);

-- 3. TABLA CONSULTANT PROJECTS MASTER
CREATE OR REPLACE TABLE `jrodriguez-sandbox.hackathon_bonus_update.consultant_projects_master` (
  project_id STRING,
  consultant_id STRING,
  project_name STRING,
  client_name STRING,
  assigned_sow_hours FLOAT64,     -- Horas máximas asignadas
  planned_start_date DATE,
  planned_end_date DATE,
  actual_start_date DATE,
  actual_end_date DATE,            -- NULL si no terminado
  project_status STRING,          -- 'Active', 'Completed', 'On Hold'
  deal_id STRING,                  -- Link al deal
  quarter INTEGER,
  year INTEGER
);


-- 4. TABLA CONSULTANT REPORT (CLICKUP DATA - SEMANAL)
CREATE OR REPLACE TABLE `jrodriguez-sandbox.hackathon_bonus_update.consultant_report` (
  report_id STRING,
  consultant_id STRING,
  project_id STRING,
  week_start_date DATE,            -- Lunes de la semana
  week_end_date DATE,              -- Viernes de la semana
  logged_hours FLOAT64,            -- Horas de la semana (normalmente 40)
  quarter INTEGER,
  year INTEGER,
  week_number INTEGER              -- Semana del año (1-52)
);

-- 5. TABLA TIME MASTER
CREATE OR REPLACE TABLE `jrodriguez-sandbox.hackathon_bonus_update.time_master` (
  time_id STRING,
  quarter INTEGER,
  year INTEGER,
  start_quarter_date DATE,
  end_quarter_date DATE,
  company_booking_target FLOAT64, -- $600,000
  recurring_target_pct FLOAT64,   -- 0.20 (20%)
  active BOOLEAN
);

-- 6. TABLA CUSTOMER SATISFACTION (SIMPLIFICADA)
CREATE OR REPLACE TABLE `jrodriguez-sandbox.hackathon_bonus_update.customer_satisfaction` (
  satisfaction_id STRING,
  project_id STRING,
  client_name STRING,
  project_name STRING,
  satisfaction_stars INTEGER,      -- 1-5 estrellas
  survey_date DATE,
  quarter INTEGER,
  year INTEGER
);

-- =====================================================
-- TABLA UNIFICADA DE RESULTADOS DE BONOS
-- =====================================================

CREATE OR REPLACE TABLE `jrodriguez-sandbox.hackathon_bonus_update.quarterly_bonus_results` (
  consultant_id STRING,
  consultant_name STRING,
  plan_type STRING,
  quarter INTEGER,
  year INTEGER,
  
  -- Company Performance (igual para todos)
  company_booking_total FLOAT64,
  company_target_achievement_pct FLOAT64,
  company_booking_bonus FLOAT64,
  recurring_business_pct FLOAT64,
  recurring_business_bonus FLOAT64,
  
  -- Sales Specific
  individual_tcv FLOAT64,
  individual_commission FLOAT64,
  
  -- Hybrid/Delivery Specific  
  project_hours FLOAT64,              -- IUV: Horas en proyectos
  total_quarter_hours FLOAT64,        -- Total horas del quarter
  project_hours_percentage FLOAT64,   -- % horas proyectos vs total
  utilization_bonus FLOAT64,          -- IUV bonus
  efficiency_bonus FLOAT64,           -- Efficiency bonus (80%+)
  
  -- Timeline Adherence (Hybrid/Delivery)
  timeline_adherence_percentage FLOAT64,
  timeline_bonus FLOAT64,
  
  -- Customer Satisfaction (todos)
  customer_satisfaction_score FLOAT64,
  customer_satisfaction_bonus FLOAT64,
  
  -- MBOs (todos)
  mbo_completed BOOLEAN,
  mbo_bonus FLOAT64,
  
  -- Total
  total_bonus FLOAT64,
  calculation_date TIMESTAMP
);
