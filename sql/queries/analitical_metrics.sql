SELECT * FROM jrodriguez-sandbox.hackathon_bonus_update.consultant_master ORDER BY plan_type, consultant_name;

-- Verificar deals (TCV por consultor)
SELECT 
  consultant_id,
  COUNT(DISTINCT deal_id) as deals_participated,
  SUM(deal_amount) as tcv_total
FROM `jrodriguez-sandbox.hackathon_bonus_update.deals_report`
WHERE quarter = 2 AND year = 2025
GROUP BY consultant_id
ORDER BY tcv_total DESC;

-- Verificar horas por consultor
SELECT 
  cr.consultant_id,
  cm.consultant_name,
  cm.plan_type,
  COUNT(*) as weeks_reported,
  SUM(cr.logged_hours) as total_hours,
  ROUND(AVG(cr.logged_hours), 1) as avg_hours_per_week
FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_report` cr
JOIN `jrodriguez-sandbox.hackathon_bonus_update.consultant_master` cm ON cr.consultant_id = cm.consultant_id
WHERE cr.quarter = 2 AND cr.year = 2025
GROUP BY cr.consultant_id, cm.consultant_name, cm.plan_type
ORDER BY total_hours DESC;

-- Verificar proyectos y SOW
SELECT 
  p.project_id,
  p.consultant_id,
  p.project_name,
  p.assigned_sow_hours,
  SUM(cr.logged_hours) as hours_logged,
  LEAST(SUM(cr.logged_hours), p.assigned_sow_hours) as effective_hours
FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_projects_master` p
LEFT JOIN `jrodriguez-sandbox.hackathon_bonus_update.consultant_report` cr 
  ON p.project_id = cr.project_id AND p.consultant_id = cr.consultant_id
WHERE p.quarter = 2 AND p.year = 2025
GROUP BY p.project_id, p.consultant_id, p.project_name, p.assigned_sow_hours
ORDER BY p.consultant_id, p.project_id;

-- Company booking total (verificar no double counting)
SELECT 
  COUNT(DISTINCT deal_id) as unique_deals,
  COUNT(*) as total_rows_with_collaborators,
  -- Company booking correcto: suma de amounts únicos por deal_id
  SUM(DISTINCT deal_amount) as company_booking_total,
  -- TCV total si sumamos todo: doble conteo en colaborativos
  SUM(deal_amount) as tcv_total_all_consultants
FROM `jrodriguez-sandbox.hackathon_bonus_update.deals_report`
WHERE quarter = 2 AND year = 2025;


-- NPS
SELECT 
  *
FROM jrodriguez-sandbox.hackathon_bonus_update.customer_satisfaction
WHERE quarter = 2 AND year = 2025
ORDER BY satisfaction_stars DESC;


-- =====================================================
-- QUERIES DE ANÁLISIS Y VALIDACIÓN
-- =====================================================

-- 1. TCV INDIVIDUAL POR CONSULTOR
SELECT 
  dr.consultant_id,
  cm.consultant_name,
  cm.plan_type,
  COUNT(DISTINCT dr.deal_id) as deals_participated,
  SUM(dr.deal_amount) as tcv_individual,
  SUM(CASE WHEN dr.is_recurring_business THEN dr.deal_amount ELSE 0 END) as recurring_tcv,
  STRING_AGG(
    CONCAT(dr.deal_name, ' ($', CAST(dr.deal_amount AS STRING), ') - ', dr.participation_type), 
    '; ' ORDER BY dr.deal_amount DESC
  ) as deals_detail
FROM `jrodriguez-sandbox.hackathon_bonus_update.deals_report` dr
JOIN `jrodriguez-sandbox.hackathon_bonus_update.consultant_master` cm ON dr.consultant_id = cm.consultant_id
WHERE dr.quarter = 2 AND dr.year = 2025
GROUP BY dr.consultant_id, cm.consultant_name, cm.plan_type
ORDER BY tcv_individual DESC;

-- 2. COMPANY BOOKING TOTAL 
WITH unique_deals AS (
  SELECT 
    deal_id,
    deal_name,
    deal_amount,
    is_recurring_business,
    close_date,
    -- Contar participantes por deal
    COUNT(*) as participants
  FROM `jrodriguez-sandbox.hackathon_bonus_update.deals_report`
  WHERE quarter = 2 AND year = 2025
  GROUP BY deal_id, deal_name, deal_amount, is_recurring_business, close_date
)
SELECT 
  COUNT(*) as total_unique_deals,
  SUM(deal_amount) as company_booking_total,
  SUM(CASE WHEN is_recurring_business THEN deal_amount ELSE 0 END) as recurring_booking,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN is_recurring_business THEN deal_amount ELSE 0 END),
    SUM(deal_amount)
  ) * 100, 2) as recurring_percentage,
  
  -- vs Company Target
  600000.00 as company_target,
  ROUND(SAFE_DIVIDE(SUM(deal_amount), 600000.00) * 100, 2) as target_achievement_pct,
  
  -- Bonus tier achieved
  CASE 
    WHEN SUM(deal_amount) >= 600000.00 * 1.5 THEN 'Level 5: $750 (150%+)'
    WHEN SUM(deal_amount) >= 600000.00 * 1.25 THEN 'Level 4: $625 (125-150%)'
    WHEN SUM(deal_amount) >= 600000.00 THEN 'Level 3: $500 (100-125%)'
    WHEN SUM(deal_amount) >= 600000.00 * 0.75 THEN 'Level 2: $375 (75-100%)'
    WHEN SUM(deal_amount) >= 600000.00 * 0.5 THEN 'Level 1: $250 (50-75%)'
    ELSE 'Level 0: $0 (Under 50%)'
  END as company_bonus_tier,
  
  -- Recurring bonus
  CASE 
    WHEN SAFE_DIVIDE(
      SUM(CASE WHEN is_recurring_business THEN deal_amount ELSE 0 END),
      SUM(deal_amount)
    ) >= 0.20 THEN 'Recurring Bonus: $250 (20%+ recurring)'
    ELSE 'No Recurring Bonus (Under 20% recurring)'
  END as recurring_bonus_status
FROM unique_deals;

-- 3. DEALS COLABORATIVOS (identificar cuáles tienen múltiples participantes)
SELECT 
  deal_id,
  deal_name,
  CONCAT('$', CAST(deal_amount AS STRING)) as deal_value,
  STRING_AGG(
    CONCAT(
      CASE 
        WHEN participation_type = 'Owner' THEN 'OWNER: '
        WHEN participation_type = 'Collaborator' THEN 'COLLAB: '
        ELSE 'OTHER: '
      END,
      consultant_id
    ), 
    ', ' ORDER BY participation_type, consultant_id
  ) as participants,
  COUNT(*) as participant_count
FROM `jrodriguez-sandbox.hackathon_bonus_update.deals_report`
WHERE quarter = 2 AND year = 2025
GROUP BY deal_id, deal_name, deal_amount
ORDER BY participant_count DESC, deal_amount DESC;

-- 4. VERIFICAR CONSULTORES ACTIVOS
SELECT 
  consultant_id,
  consultant_name,
  plan_type,
  eligible_for_comp,
  active
FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_master` 
ORDER BY plan_type, consultant_name;

-- 5. VERIFICAR HORAS POR CONSULTOR
SELECT 
  cr.consultant_id,
  cm.consultant_name,
  cm.plan_type,
  COUNT(*) as weeks_reported,
  SUM(cr.logged_hours) as total_hours,
  ROUND(AVG(cr.logged_hours), 1) as avg_hours_per_week,
  MIN(cr.week_start_date) as first_week,
  MAX(cr.week_end_date) as last_week
FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_report` cr
JOIN `jrodriguez-sandbox.hackathon_bonus_update.consultant_master` cm ON cr.consultant_id = cm.consultant_id
WHERE cr.quarter = 2 AND cr.year = 2025
GROUP BY cr.consultant_id, cm.consultant_name, cm.plan_type
ORDER BY total_hours DESC;

-- 6. VERIFICAR EFFECTIVE HOURS VS SOW
SELECT 
  p.project_id,
  p.consultant_id,
  cm.consultant_name,
  p.project_name,
  p.assigned_sow_hours,
  COALESCE(SUM(cr.logged_hours), 0) as hours_logged,
  LEAST(COALESCE(SUM(cr.logged_hours), 0), p.assigned_sow_hours) as effective_hours,
  CASE 
    WHEN COALESCE(SUM(cr.logged_hours), 0) > p.assigned_sow_hours 
    THEN CONCAT('OVER SOW by ', COALESCE(SUM(cr.logged_hours), 0) - p.assigned_sow_hours, ' hours')
    ELSE 'Within SOW limits'
  END as sow_status
FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_projects_master` p
JOIN `jrodriguez-sandbox.hackathon_bonus_update.consultant_master` cm ON p.consultant_id = cm.consultant_id
LEFT JOIN `jrodriguez-sandbox.hackathon_bonus_update.consultant_report` cr 
  ON p.project_id = cr.project_id AND p.consultant_id = cr.consultant_id
WHERE p.quarter = 2 AND p.year = 2025
GROUP BY p.project_id, p.consultant_id, cm.consultant_name, p.project_name, p.assigned_sow_hours
ORDER BY p.consultant_id, p.project_id;

-- 7. RESUMEN EJECUTIVO POR CONSULTOR
SELECT 
  cm.consultant_name,
  cm.plan_type,
  
  -- TCV Metrics
  COALESCE(tcv.tcv_individual, 0) as tcv,
  COALESCE(tcv.deals_participated, 0) as deals_count,
  
  -- Hours Metrics (solo para Hybrid/Delivery)
  CASE 
    WHEN cm.plan_type IN ('Hybrid', 'Delivery') THEN COALESCE(hours.total_hours, 0)
    ELSE NULL
  END as hours_logged,
  
  -- Expected Bonus Tiers
  CASE cm.plan_type
    WHEN 'Sales' THEN 
      CASE 
        WHEN COALESCE(tcv.tcv_individual, 0) >= 1000000 THEN CONCAT('TCV >=1M: ', ROUND(COALESCE(tcv.tcv_individual, 0) * 0.02, 0), ' commission')
        WHEN COALESCE(tcv.tcv_individual, 0) >= 500000 THEN CONCAT('TCV 500K-1M: ', ROUND(COALESCE(tcv.tcv_individual, 0) * 0.015, 0), ' commission')
        WHEN COALESCE(tcv.tcv_individual, 0) >= 50000 THEN CONCAT('TCV 50K-500K: ', ROUND(COALESCE(tcv.tcv_individual, 0) * 0.01, 0), ' commission')
        ELSE 'TCV < 50K: No commission'
      END
    WHEN 'Hybrid' THEN 
      CASE 
        WHEN COALESCE(hours.total_hours, 0) > 225 THEN 'Hours > 225: $400'
        WHEN COALESCE(hours.total_hours, 0) >= 175 THEN 'Hours 175-225: $300'
        WHEN COALESCE(hours.total_hours, 0) >= 100 THEN 'Hours 100-175: $150'
        ELSE 'Hours < 100: $0'
      END
    WHEN 'Delivery' THEN 
      CASE 
        WHEN COALESCE(hours.total_hours, 0) > 450 THEN 'Hours > 450: $600'
        WHEN COALESCE(hours.total_hours, 0) >= 350 THEN 'Hours 350-450: $500'
        WHEN COALESCE(hours.total_hours, 0) >= 200 THEN 'Hours 200-350: $250'
        ELSE 'Hours < 200: $0'
      END
  END as expected_primary_bonus

FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_master` cm

LEFT JOIN (
  SELECT 
    consultant_id,
    SUM(deal_amount) as tcv_individual,
    COUNT(DISTINCT deal_id) as deals_participated
  FROM `jrodriguez-sandbox.hackathon_bonus_update.deals_report`
  WHERE quarter = 2 AND year = 2025
  GROUP BY consultant_id
) tcv ON cm.consultant_id = tcv.consultant_id

LEFT JOIN (
  SELECT 
    consultant_id,
    SUM(logged_hours) as total_hours
  FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_report`
  WHERE quarter = 2 AND year = 2025
  GROUP BY consultant_id
) hours ON cm.consultant_id = hours.consultant_id

WHERE cm.eligible_for_comp = TRUE AND cm.active = TRUE
ORDER BY cm.plan_type, tcv_individual DESC, hours.total_hours DESC;

-- 8. VALIDACIÓN DE DATOS POR TABLA
SELECT 'deals_report' as table_name, COUNT(*) as total_rows FROM `jrodriguez-sandbox.hackathon_bonus_update.deals_report`
UNION ALL
SELECT 'consultant_master' as table_name, COUNT(*) as total_rows FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_master`
UNION ALL
SELECT 'consultant_report' as table_name, COUNT(*) as total_rows FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_report`
UNION ALL
SELECT 'consultant_projects_master' as table_name, COUNT(*) as total_rows FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_projects_master`
UNION ALL
SELECT 'customer_satisfaction' as table_name, COUNT(*) as total_rows FROM `jrodriguez-sandbox.hackathon_bonus_update.customer_satisfaction`
UNION ALL
SELECT 'time_master' as table_name, COUNT(*) as total_rows FROM `jrodriguez-sandbox.hackathon_bonus_update.time_master`
ORDER BY table_name;

-- =====================================================
-- QUERY PARA EJECUTAR EL PROCEDIMIENTO
-- =====================================================

-- Ejecutar cálculo para Q2 2025
CALL `jrodriguez-sandbox.hackathon_bonus_update.calculate_quarterly_bonuses`(2, 2025);

-- Ver resultados 
SELECT 
  consultant_name,
  plan_type,
  ROUND(company_booking_bonus, 0) as company_bonus,
  ROUND(recurring_business_bonus, 0) as recurring_bonus,
  ROUND(individual_commission, 0) as tcv_commission,
  ROUND(project_hours, 0) as project_hrs,
  ROUND(project_hours_percentage, 1) as efficiency_pct,
  ROUND(utilization_bonus, 0) as utilization_bonus,
  ROUND(efficiency_bonus, 0) as efficiency_bonus,
  ROUND(timeline_bonus, 0) as timeline_bonus,
  ROUND(customer_satisfaction_bonus, 0) as satisfaction_bonus,
  ROUND(mbo_bonus, 0) as mbo_bonus,
  ROUND(total_bonus, 0) as total_bonus
FROM `jrodriguez-sandbox.hackathon_bonus_update.quarterly_bonus_results`
WHERE quarter = 2 AND year = 2025
ORDER BY plan_type, total_bonus DESC;