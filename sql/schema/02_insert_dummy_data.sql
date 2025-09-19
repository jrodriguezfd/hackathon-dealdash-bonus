-- =====================================================
-- DATA DUMMY PARA Q2 2025
-- =====================================================

-- CONSULTORES
INSERT INTO `jrodriguez-sandbox.hackathon_bonus_update.consultant_master` VALUES
('CONS001', 'Rodolfo Solar', 'Sales', TRUE, TRUE),
('CONS002', 'Anthony Alarcon', 'Delivery', TRUE, TRUE),  -- Cambio a Delivery
('CONS003', 'Julian Rodriguez', 'Hybrid', TRUE, TRUE);

-- TIME MASTER Q2 2025
INSERT INTO `jrodriguez-sandbox.hackathon_bonus_update.time_master` VALUES
('Q2_2025', 2, 2025, '2025-04-01', '2025-06-30', 600000.00, 0.20, TRUE);

-- DEALS REPORT (RODOLFO + COLABORATIVOS)
INSERT INTO `jrodriguez-sandbox.hackathon_bonus_update.deals_report` VALUES
-- Rodolfo Solar (Sales Owner) - Datos reales adaptados a Q2
('32309138752', 'CONS001', 2, 2025, 'Minera Chinalco GCP Billing Transfer', 40000.00, '2025-04-30', 'Owner', FALSE, 'Minera Chinalco', 'Google', 'Cloud Consumption'),
('32256468133', 'CONS001', 2, 2025, 'Atlantic City BigQuery ML', 10540.00, '2025-05-26', 'Owner', FALSE, 'Atlantic City', 'Google', 'PS'),
('29904461312', 'CONS001', 2, 2025, 'Etafashion Price Optimization', 37420.00, '2025-04-29', 'Owner', FALSE, 'Etafashion', 'Google', 'PS'),
('23124565023', 'CONS001', 2, 2025, 'Chinalco Data Governance', 25800.00, '2025-05-10', 'Owner', TRUE, 'Minera Chinalco', '', 'PS'),
('22389628059', 'CONS001', 2, 2025, 'Santa Elena Data Insights', 4000.00, '2025-06-14', 'Owner', TRUE, 'Santa Elena', 'Google', 'PS'),
('41582739461', 'CONS001', 2, 2025, 'Financial Services AI Platform', 120000.00, '2025-04-05', 'Owner', TRUE, 'FinTech Global', 'Google', 'PS'),
('38294756193', 'CONS001', 2, 2025, 'Logistics Optimization Suite', 85000.00, '2025-05-08', 'Owner', FALSE, 'LogiCorp International', 'Direct', 'PS'),
('45729384057', 'CONS001', 2, 2025, 'E-commerce Data Analytics', 75000.00, '2025-05-28', 'Owner', TRUE, 'ShopTech Solutions', 'Google', 'PS'),
('39847562810', 'CONS001', 2, 2025, 'Energy Sector Cloud Migration', 110000.00, '2025-06-03', 'Owner', FALSE, 'GreenEnergy Corp', 'Google', 'Cloud Consumption'),
('42681035947', 'CONS001', 2, 2025, 'Government Data Modernization', 95000.00, '2025-06-20', 'Owner', TRUE, 'Municipal Authority', '', 'PS'),


-- Julian Rodriguez (Hybrid Collaborator en algunos deals)
('23124565023', 'CONS003', 2, 2025, 'Chinalco Data Governance', 25800.00, '2025-05-10', 'Collaborator', TRUE, 'Minera Chinalco', '', 'PS'),
('22389628059', 'CONS003', 2, 2025, 'Santa Elena Data Insights', 4000.00, '2025-06-14', 'Collaborator', TRUE, 'Santa Elena', 'Google', 'PS'),
('38294756193', 'CONS003', 2, 2025, 'Logistics Optimization Suite', 85000.00, '2025-05-08', 'Collaborator', FALSE, 'LogiCorp International', 'Direct', 'PS'),
('45729384057', 'CONS003', 2, 2025, 'E-commerce Data Analytics', 75000.00, '2025-05-28', 'Collaborator', TRUE, 'ShopTech Solutions', 'Google', 'PS');

-- PROJECTS MASTER
INSERT INTO `jrodriguez-sandbox.hackathon_bonus_update.consultant_projects_master` VALUES
-- Anthony Alarcon (Delivery) - Proyectos de los deals colaborativos
('PROJ001', 'CONS002', 'Atlantic City ML Implementation', 'Atlantic City', 320.0, '2025-05-01', '2025-07-30', '2025-05-01', NULL, 'Active', '32256468133', 2, 2025),
('PROJ002', 'CONS002', 'Etafashion Price Engine Development', 'Etafashion', 280.0, '2025-04-15', '2025-06-30', '2025-04-15', '2025-06-28', 'Completed', '29904461312', 2, 2025),

-- Julian Rodriguez (Hybrid) - Proyectos de los deals colaborativos  
('PROJ003', 'CONS003', 'Chinalco Data Governance Setup', 'Minera Chinalco', 200.0, '2025-04-01', '2025-06-15', '2025-04-01', '2025-06-10', 'Completed', '23124565023', 2, 2025),
('PROJ004', 'CONS003', 'Santa Elena Analytics Dashboard', 'Santa Elena', 120.0, '2025-06-01', '2025-08-15', '2025-06-01', NULL, 'Active', '22389628059', 2, 2025);

-- =====================================================
-- DATA DUMMY: REPORTE DE HORAS SEMANAL Q2 2025
-- =====================================================

-- Q2 2025 tiene 13 semanas (del 1 de abril al 30 de junio)
-- Semanas: 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26

-- ANTHONY ALARCON (DELIVERY) - ~240 horas total en Q2
INSERT INTO `jrodriguez-sandbox.hackathon_bonus_update.consultant_report` VALUES
-- ABRIL 2025 (Semanas 14-17) - Proyecto Etafashion
('RPT001', 'CONS002', 'PROJ002', '2025-04-07', '2025-04-11', 40.0, 2, 2025, 15),
('RPT002', 'CONS002', 'PROJ002', '2025-04-14', '2025-04-18', 40.0, 2, 2025, 16),
('RPT003', 'CONS002', 'PROJ002', '2025-04-21', '2025-04-25', 40.0, 2, 2025, 17),
('RPT004', 'CONS002', 'PROJ002', '2025-04-28', '2025-05-02', 40.0, 2, 2025, 18),

-- MAYO 2025 (Semanas 18-22) - Dividido entre Etafashion y Atlantic City
('RPT005', 'CONS002', 'PROJ002', '2025-05-05', '2025-05-09', 32.0, 2, 2025, 19),  -- Terminando Etafashion
('RPT006', 'CONS002', 'PROJ001', '2025-05-05', '2025-05-09', 8.0, 2, 2025, 19),   -- Empezando Atlantic City
('RPT007', 'CONS002', 'PROJ001', '2025-05-12', '2025-05-16', 40.0, 2, 2025, 20),
('RPT008', 'CONS002', 'PROJ001', '2025-05-19', '2025-05-23', 40.0, 2, 2025, 21),
('RPT009', 'CONS002', 'PROJ001', '2025-05-26', '2025-05-30', 40.0, 2, 2025, 22),

-- JUNIO 2025 (Semanas 23-26) - Solo Atlantic City
('RPT010', 'CONS002', 'PROJ001', '2025-06-02', '2025-06-06', 40.0, 2, 2025, 23),
('RPT011', 'CONS002', 'PROJ001', '2025-06-09', '2025-06-13', 40.0, 2, 2025, 24),
('RPT012', 'CONS002', 'PROJ001', '2025-06-16', '2025-06-20', 40.0, 2, 2025, 25),
('RPT013', 'CONS002', 'PROJ001', '2025-06-23', '2025-06-27', 32.0, 2, 2025, 26);  -- Última semana parcial

-- JULIAN RODRIGUEZ (HYBRID) - ~160 horas total en Q2 (menos utilización)
INSERT INTO `jrodriguez-sandbox.hackathon_bonus_update.consultant_report` VALUES
-- ABRIL 2025 (Semanas 14-17) - Solo Chinalco
('RPT014', 'CONS003', 'PROJ003', '2025-04-07', '2025-04-11', 32.0, 2, 2025, 15),  -- Tiempo parcial para ventas
('RPT015', 'CONS003', 'PROJ003', '2025-04-14', '2025-04-18', 32.0, 2, 2025, 16),
('RPT016', 'CONS003', 'PROJ003', '2025-04-21', '2025-04-25', 40.0, 2, 2025, 17),
('RPT017', 'CONS003', 'PROJ003', '2025-04-28', '2025-05-02', 40.0, 2, 2025, 18),

-- MAYO 2025 (Semanas 18-22) - Terminando Chinalco
('RPT018', 'CONS003', 'PROJ003', '2025-05-05', '2025-05-09', 32.0, 2, 2025, 19),
('RPT019', 'CONS003', 'PROJ003', '2025-05-12', '2025-05-16', 24.0, 2, 2025, 20),  -- Últimas semanas de proyecto
('RPT020', 'CONS003', 'PROJ003', '2025-05-19', '2025-05-23', 16.0, 2, 2025, 21),  -- Cierre de proyecto
('RPT021', 'CONS003', 'PROJ003', '2025-05-26', '2025-05-30', 8.0, 2, 2025, 22),   -- Documentación final

-- JUNIO 2025 (Semanas 23-26) - Empezando Santa Elena (menos horas, más ventas)
('RPT022', 'CONS003', 'PROJ004', '2025-06-02', '2025-06-06', 24.0, 2, 2025, 23),
('RPT023', 'CONS003', 'PROJ004', '2025-06-09', '2025-06-13', 24.0, 2, 2025, 24),
('RPT024', 'CONS003', 'PROJ004', '2025-06-16', '2025-06-20', 24.0, 2, 2025, 25),
('RPT025', 'CONS003', 'PROJ004', '2025-06-23', '2025-06-27', 16.0, 2, 2025, 26);

-- CUSTOMER SATISFACTION
INSERT INTO `jrodriguez-sandbox.hackathon_bonus_update.customer_satisfaction` VALUES
('SAT001', 'PROJ002', 'Etafashion', 'Etafashion Price Engine Development', 5, '2025-06-30', 2, 2025),
('SAT002', 'PROJ003', 'Minera Chinalco', 'Chinalco Data Governance Setup', 4, '2025-06-15', 2, 2025),
('SAT003', 'PROJ001', 'Atlantic City', 'Atlantic City ML Implementation', 3, '2025-06-25', 2, 2025);
