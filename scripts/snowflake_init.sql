-- ============================================================================
-- 1. CRÉATION DU COMPOSANT DE CALCUL (ENTREPÔT)
-- ============================================================================
USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS COMBO_COMPUTE_WH 
    WITH WAREHOUSE_SIZE = 'XSMALL' 
    AUTO_SUSPEND = 60 
    AUTO_RESUME = TRUE 
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Entrepôt de calcul principal pour le projet Combo';

-- ============================================================================
-- 2. CRÉATION DE LA BASE DE DONNÉES ET DU SCHÉMA RAW
-- ============================================================================
CREATE DATABASE IF NOT EXISTS COMBO_PROJECT 
    COMMENT = 'Base de données principale pour le projet Combo';

USE DATABASE COMBO_PROJECT;


-- Création du schéma RAW (pour accueillir les données brutes : shifts, rests, etc.)
CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Schéma contenant les données sources brutes inchangées';
