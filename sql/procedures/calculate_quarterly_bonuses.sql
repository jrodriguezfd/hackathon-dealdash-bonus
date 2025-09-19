-- =====================================================
-- PROCEDIMIENTO PRINCIPAL DE CÁLCULO DE BONOS - NPS GLOBAL
-- =====================================================

CREATE OR REPLACE PROCEDURE `jrodriguez-sandbox.hackathon_bonus_update.calculate_quarterly_bonuses`(
  IN target_quarter INT64,
  IN target_year INT64
)
BEGIN
  
  -- Limpiar resultados previos
  DELETE FROM `jrodriguez-sandbox.hackathon_bonus_update.quarterly_bonus_results` 
  WHERE quarter = target_quarter AND year = target_year;
  
  -- Insertar resultados calculados
  INSERT INTO `jrodriguez-sandbox.hackathon_bonus_update.quarterly_bonus_results`
  WITH 
  
  -- 1. COMPANY PERFORMANCE (igual para todos) + NPS GLOBAL
  company_metrics AS (
    SELECT 
      target_quarter as quarter,
      target_year as year,
      600000.00 as company_target,
      
      -- Company booking (suma de deals únicos)
      SUM(deal_amount) as company_booking_total,
      
      -- Achievement percentage
      ROUND(SAFE_DIVIDE(SUM(deal_amount), 600000.00) * 100, 2) as target_achievement_pct,
      
      -- Company booking bonus
      CASE 
        WHEN SUM(deal_amount) >= 600000.00 * 1.5 THEN 750.0
        WHEN SUM(deal_amount) >= 600000.00 * 1.25 THEN 625.0
        WHEN SUM(deal_amount) >= 600000.00 THEN 500.0
        WHEN SUM(deal_amount) >= 600000.00 * 0.75 THEN 375.0
        WHEN SUM(deal_amount) >= 600000.00 * 0.5 THEN 250.0
        ELSE 0.0
      END as company_booking_bonus,
      
      -- Recurring business metrics
      SUM(CASE WHEN is_recurring_business THEN deal_amount ELSE 0 END) as recurring_booking,
      ROUND(SAFE_DIVIDE(
        SUM(CASE WHEN is_recurring_business THEN deal_amount ELSE 0 END),
        SUM(deal_amount)
      ) * 100, 2) as recurring_business_pct,
      
      -- Recurring business bonus
      CASE 
        WHEN SAFE_DIVIDE(
          SUM(CASE WHEN is_recurring_business THEN deal_amount ELSE 0 END),
          SUM(deal_amount)
        ) >= 0.20 THEN 250.0
        ELSE 0.0
      END as recurring_business_bonus,
      
      -- NPS GLOBAL de la empresa
      (SELECT AVG(satisfaction_stars) 
       FROM `jrodriguez-sandbox.hackathon_bonus_update.customer_satisfaction` 
       WHERE quarter = target_quarter AND year = target_year) as company_nps,
       
      -- Customer satisfaction bonus global (si empresa alcanza NPS > 4.5)
      CASE 
        WHEN (SELECT AVG(satisfaction_stars) 
              FROM `jrodriguez-sandbox.hackathon_bonus_update.customer_satisfaction` 
              WHERE quarter = target_quarter AND year = target_year) > 4.5 THEN TRUE
        ELSE FALSE
      END as nps_bonus_achieved
      
    FROM (
      SELECT DISTINCT deal_id, deal_amount, is_recurring_business
      FROM `jrodriguez-sandbox.hackathon_bonus_update.deals_report`
      WHERE quarter = target_quarter AND year = target_year
    ) unique_deals
  ),
  
  -- 2. INDIVIDUAL TCV (Sales y Hybrid)
  individual_tcv AS (
    SELECT 
      consultant_id,
      SUM(deal_amount) as tcv_total
    FROM `jrodriguez-sandbox.hackathon_bonus_update.deals_report`
    WHERE quarter = target_quarter AND year = target_year
    GROUP BY consultant_id
  ),
  
  -- 3. PROJECT HOURS & EFFICIENCY (Hybrid y Delivery)
  project_utilization AS (
    SELECT 
      cr.consultant_id,
      -- Horas en proyectos (IUV)
      SUM(cr.logged_hours) as project_hours,
      -- Total horas del quarter (para efficiency calculation)
      (SELECT SUM(logged_hours) 
       FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_report` cr2 
       WHERE cr2.consultant_id = cr.consultant_id 
         AND cr2.quarter = target_quarter 
         AND cr2.year = target_year) as total_quarter_hours
    FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_report` cr
    JOIN `jrodriguez-sandbox.hackathon_bonus_update.consultant_projects_master` cpm 
      ON cr.project_id = cpm.project_id AND cr.consultant_id = cpm.consultant_id
    WHERE cr.quarter = target_quarter AND cr.year = target_year
    GROUP BY cr.consultant_id
  ),
  
  -- 4. TIMELINE ADHERENCE (Hybrid y Delivery)
  timeline_metrics AS (
    SELECT 
      consultant_id,
      COUNT(*) as total_completed_projects,
      SUM(CASE WHEN actual_end_date <= planned_end_date THEN 1 ELSE 0 END) as on_time_projects,
      SAFE_DIVIDE(
        SUM(CASE WHEN actual_end_date <= planned_end_date THEN 1 ELSE 0 END),
        COUNT(*)
      ) * 100 as timeline_adherence_pct
    FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_projects_master`
    WHERE quarter = target_quarter 
      AND year = target_year
      AND actual_end_date IS NOT NULL  -- Solo proyectos completados
    GROUP BY consultant_id
  ),
  
  -- 5. CONSULTORES ELEGIBLES
  eligible_consultants AS (
    SELECT 
      consultant_id,
      consultant_name,
      plan_type
    FROM `jrodriguez-sandbox.hackathon_bonus_update.consultant_master`
    WHERE eligible_for_comp = TRUE AND active = TRUE
  )
  
  -- CÁLCULO FINAL
  SELECT 
    ec.consultant_id,
    ec.consultant_name,
    ec.plan_type,
    target_quarter as quarter,
    target_year as year,
    
    -- Company metrics (iguales para todos)
    cm.company_booking_total,
    cm.target_achievement_pct as company_target_achievement_pct,
    cm.company_booking_bonus, 
    cm.recurring_business_pct,
    cm.recurring_business_bonus,
    
    -- Individual TCV
    COALESCE(itcv.tcv_total, 0) as individual_tcv,
    
    -- Individual commission (solo Sales)
    CASE 
      WHEN ec.plan_type = 'Sales' THEN
        CASE 
          WHEN COALESCE(itcv.tcv_total, 0) >= 1000000 THEN COALESCE(itcv.tcv_total, 0) * 0.02
          WHEN COALESCE(itcv.tcv_total, 0) >= 500000 THEN COALESCE(itcv.tcv_total, 0) * 0.015
          WHEN COALESCE(itcv.tcv_total, 0) >= 50000 THEN COALESCE(itcv.tcv_total, 0) * 0.01
          ELSE 0.0
        END
      ELSE 0.0
    END as individual_commission,
    
    -- Project hours (IUV para Hybrid/Delivery)
    CASE 
      WHEN ec.plan_type IN ('Hybrid', 'Delivery') THEN COALESCE(pu.project_hours, 0)
      ELSE NULL
    END as project_hours,
    
    -- Total quarter hours
    CASE 
      WHEN ec.plan_type IN ('Hybrid', 'Delivery') THEN COALESCE(pu.total_quarter_hours, 0)
      ELSE NULL
    END as total_quarter_hours,
    
    -- Project hours percentage (efficiency metric)
    CASE 
      WHEN ec.plan_type IN ('Hybrid', 'Delivery') THEN 
        ROUND(SAFE_DIVIDE(COALESCE(pu.project_hours, 0), COALESCE(pu.total_quarter_hours, 0)) * 100, 2)
      ELSE NULL
    END as project_hours_percentage,
    
    -- Utilization bonus (IUV)
    CASE 
      WHEN ec.plan_type = 'Hybrid' THEN
        CASE 
          WHEN COALESCE(pu.project_hours, 0) > 225 THEN 400.0
          WHEN COALESCE(pu.project_hours, 0) >= 175 THEN 300.0
          WHEN COALESCE(pu.project_hours, 0) >= 100 THEN 150.0
          ELSE 0.0
        END
      WHEN ec.plan_type = 'Delivery' THEN
        CASE 
          WHEN COALESCE(pu.project_hours, 0) > 450 THEN 600.0
          WHEN COALESCE(pu.project_hours, 0) >= 350 THEN 500.0
          WHEN COALESCE(pu.project_hours, 0) >= 200 THEN 250.0
          ELSE 0.0
        END
      ELSE 0.0
    END as utilization_bonus,
    
    -- Efficiency bonus (80%+ project hours vs total)
    CASE 
      WHEN ec.plan_type = 'Hybrid' AND 
           SAFE_DIVIDE(COALESCE(pu.project_hours, 0), COALESCE(pu.total_quarter_hours, 0)) * 100 >= 80 THEN 150.0
      WHEN ec.plan_type = 'Delivery' AND 
           SAFE_DIVIDE(COALESCE(pu.project_hours, 0), COALESCE(pu.total_quarter_hours, 0)) * 100 >= 80 THEN 250.0
      ELSE 0.0
    END as efficiency_bonus,
    
    -- Timeline adherence
    CASE 
      WHEN ec.plan_type IN ('Hybrid', 'Delivery') THEN COALESCE(tm.timeline_adherence_pct, 0)
      ELSE NULL
    END as timeline_adherence_percentage,
    
    -- Timeline bonus
    CASE 
      WHEN ec.plan_type = 'Hybrid' AND COALESCE(tm.timeline_adherence_pct, 0) >= 40 THEN 150.0
      WHEN ec.plan_type = 'Delivery' AND COALESCE(tm.timeline_adherence_pct, 0) >= 50 THEN 250.0
      ELSE 0.0
    END as timeline_bonus,
    
    -- Customer satisfaction GLOBAL (mismo NPS para todos)
    COALESCE(cm.company_nps, 0) as customer_satisfaction_score,
    
    -- Customer satisfaction bonus GLOBAL
    CASE 
      WHEN cm.nps_bonus_achieved THEN
        CASE ec.plan_type
          WHEN 'Sales' THEN 500.0
          WHEN 'Hybrid' THEN 250.0
          WHEN 'Delivery' THEN 250.0
        END
      ELSE 0.0
    END as customer_satisfaction_bonus,
    
    -- MBOs (Para POC = TRUE siempre)
    TRUE as mbo_completed,
    
    -- MBO bonus
    CASE ec.plan_type
      WHEN 'Sales' THEN 500.0
      WHEN 'Hybrid' THEN 250.0
      WHEN 'Delivery' THEN 250.0
    END as mbo_bonus,
    
    -- TOTAL BONUS CALCULATION
    cm.company_booking_bonus +
    cm.recurring_business_bonus +
    -- Individual commission (Sales only)
    (CASE 
      WHEN ec.plan_type = 'Sales' THEN
        CASE 
          WHEN COALESCE(itcv.tcv_total, 0) >= 1000000 THEN COALESCE(itcv.tcv_total, 0) * 0.02
          WHEN COALESCE(itcv.tcv_total, 0) >= 500000 THEN COALESCE(itcv.tcv_total, 0) * 0.015
          WHEN COALESCE(itcv.tcv_total, 0) >= 50000 THEN COALESCE(itcv.tcv_total, 0) * 0.01
          ELSE 0.0
        END
      ELSE 0.0
    END) +
    -- Utilization bonus
    (CASE 
      WHEN ec.plan_type = 'Hybrid' THEN
        CASE 
          WHEN COALESCE(pu.project_hours, 0) > 225 THEN 400.0
          WHEN COALESCE(pu.project_hours, 0) >= 175 THEN 300.0
          WHEN COALESCE(pu.project_hours, 0) >= 100 THEN 150.0
          ELSE 0.0
        END
      WHEN ec.plan_type = 'Delivery' THEN
        CASE 
          WHEN COALESCE(pu.project_hours, 0) > 450 THEN 600.0
          WHEN COALESCE(pu.project_hours, 0) >= 350 THEN 500.0
          WHEN COALESCE(pu.project_hours, 0) >= 200 THEN 250.0
          ELSE 0.0
        END
      ELSE 0.0
    END) +
    -- Efficiency bonus
    (CASE 
      WHEN ec.plan_type = 'Hybrid' AND 
           SAFE_DIVIDE(COALESCE(pu.project_hours, 0), COALESCE(pu.total_quarter_hours, 0)) * 100 >= 80 THEN 150.0
      WHEN ec.plan_type = 'Delivery' AND 
           SAFE_DIVIDE(COALESCE(pu.project_hours, 0), COALESCE(pu.total_quarter_hours, 0)) * 100 >= 80 THEN 250.0
      ELSE 0.0
    END) +
    -- Timeline bonus
    (CASE 
      WHEN ec.plan_type = 'Hybrid' AND COALESCE(tm.timeline_adherence_pct, 0) >= 40 THEN 150.0
      WHEN ec.plan_type = 'Delivery' AND COALESCE(tm.timeline_adherence_pct, 0) >= 50 THEN 250.0
      ELSE 0.0
    END) +
    -- Customer satisfaction bonus GLOBAL
    (CASE 
      WHEN cm.nps_bonus_achieved THEN
        CASE ec.plan_type
          WHEN 'Sales' THEN 500.0
          WHEN 'Hybrid' THEN 250.0
          WHEN 'Delivery' THEN 250.0
        END
      ELSE 0.0
    END) +
    -- MBO bonus
    (CASE ec.plan_type
      WHEN 'Sales' THEN 500.0
      WHEN 'Hybrid' THEN 250.0
      WHEN 'Delivery' THEN 250.0
    END) as total_bonus,
    
    CURRENT_TIMESTAMP() as calculation_date
    
  FROM eligible_consultants ec
  CROSS JOIN company_metrics cm
  LEFT JOIN individual_tcv itcv ON ec.consultant_id = itcv.consultant_id
  LEFT JOIN project_utilization pu ON ec.consultant_id = pu.consultant_id
  LEFT JOIN timeline_metrics tm ON ec.consultant_id = tm.consultant_id
  
  ORDER BY ec.plan_type, ec.consultant_name;

END;