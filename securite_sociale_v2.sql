-- =====================================================================
-- BASE DE DONNÉES : securite_sociale_v2
-- Projet : Application mobile de sécurité — RDC (Police / Citoyens)
-- SGBD : MySQL 8.0+ / utf8mb4_unicode_ci
-- Version : 2.1.0
--
-- Différences avec la v2.0.0 d'origine (corrections) :
--   * idempotent : DROP VIEW / DROP TABLE en amont
--   * TIMESTAMP -> DATETIME (évite la limite 2038 pour l'archivage judiciaire)
--   * users.role ENUM supprimé : RBAC (roles/user_role/role_permission) = source unique
--   * tables notifications + verification_tokens + token_denylist ajoutées
--   * tables Laravel abandonnées supprimées (personal_access_tokens, jobs,
--     failed_jobs, migrations) : le backend est Flask + JWT stateless
--   * alertes.id_user et objets.id_user_proprietaire : CASCADE -> RESTRICT
--     (la suppression d'un compte ne doit pas effacer des preuves)
--   * v_amis_acceptes réécrite (double sens + filtre par utilisateur)
--   * CHECK constraints, index composites, UNIQUE(id_province, nom)
--   * seeds : 26 provinces, villes, commissariats, rôles, permissions,
--     types d'alertes, types d'objets, compte admin
-- =====================================================================

CREATE DATABASE IF NOT EXISTS `securite_sociale_v2`
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `securite_sociale_v2`;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- =====================================================================
-- 0. SUPPRESSION DE L'EXISTANT (idempotence)
-- =====================================================================

DROP VIEW IF EXISTS `v_amis_acceptes`;
DROP VIEW IF EXISTS `v_alertes_detail`;
DROP VIEW IF EXISTS `v_cas_detail`;
DROP VIEW IF EXISTS `v_objets_detail`;
DROP VIEW IF EXISTS `v_users_roles`;
DROP VIEW IF EXISTS `v_dernieres_positions`;

DROP TABLE IF EXISTS `token_denylist`;
DROP TABLE IF EXISTS `verification_tokens`;
DROP TABLE IF EXISTS `notifications`;
DROP TABLE IF EXISTS `partages`;
DROP TABLE IF EXISTS `audit_logs`;
DROP TABLE IF EXISTS `preuves`;
DROP TABLE IF EXISTS `localisations`;
DROP TABLE IF EXISTS `interventions`;
DROP TABLE IF EXISTS `objets`;
DROP TABLE IF EXISTS `type_objets`;
DROP TABLE IF EXISTS `cas`;
DROP TABLE IF EXISTS `alertes`;
DROP TABLE IF EXISTS `typealertes`;
DROP TABLE IF EXISTS `notes`;
DROP TABLE IF EXISTS `demandes`;
DROP TABLE IF EXISTS `role_permission`;
DROP TABLE IF EXISTS `user_role`;
DROP TABLE IF EXISTS `permissions`;
DROP TABLE IF EXISTS `roles`;
DROP TABLE IF EXISTS `users`;
DROP TABLE IF EXISTS `commissariats`;
DROP TABLE IF EXISTS `villes`;
DROP TABLE IF EXISTS `provinces`;

-- =====================================================================
-- 1. RÉFÉRENTIELS GÉOGRAPHIQUES
-- =====================================================================

CREATE TABLE `provinces` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(10) NOT NULL,
  `nom` VARCHAR(100) NOT NULL,
  `chef_lieu` VARCHAR(100) NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_provinces_code` (`code`),
  UNIQUE KEY `uk_provinces_nom` (`nom`),
  KEY `idx_provinces_nom` (`nom`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `villes` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_province` INT UNSIGNED NOT NULL,
  `nom` VARCHAR(100) NOT NULL,
  `latitude` DECIMAL(10,7) NULL,
  `longitude` DECIMAL(10,7) NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_villes_province_nom` (`id_province`, `nom`),
  KEY `idx_villes_nom` (`nom`),
  CONSTRAINT `fk_villes_province` FOREIGN KEY (`id_province`) REFERENCES `provinces` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 1bis. COMMUNES  (province -> ville -> commune -> commissariat)
-- =====================================================================

CREATE TABLE `communes` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_ville` INT UNSIGNED NOT NULL,
  `code` VARCHAR(20) NULL,
  `nom` VARCHAR(100) NOT NULL,
  `latitude` DECIMAL(10,7) NULL,
  `longitude` DECIMAL(10,7) NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_communes_ville_nom` (`id_ville`, `nom`),
  KEY `idx_communes_nom` (`nom`),
  CONSTRAINT `fk_communes_ville` FOREIGN KEY (`id_ville`) REFERENCES `villes` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 2. COMMISSARIATS
-- =====================================================================

CREATE TABLE `commissariats` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(20) NOT NULL,
  `nom` VARCHAR(150) NOT NULL,
  `id_province` INT UNSIGNED NULL,
  `id_ville` INT UNSIGNED NULL,
  `id_commune` INT UNSIGNED NULL,
  `adresse` VARCHAR(255) NULL,
  `telephone` VARCHAR(20) NULL,
  `email` VARCHAR(100) NULL,
  `latitude` DECIMAL(10,7) NULL,
  `longitude` DECIMAL(10,7) NULL,
  `responsable_id` INT UNSIGNED NULL,
  `statut` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_commissariats_code` (`code`),
  KEY `idx_commissariats_province` (`id_province`),
  KEY `idx_commissariats_ville` (`id_ville`),
  KEY `idx_commissariats_commune` (`id_commune`),
  KEY `idx_commissariats_responsable` (`responsable_id`),
  KEY `idx_commissariats_statut` (`statut`),
  KEY `idx_commissariats_geo` (`latitude`, `longitude`),
  CONSTRAINT `fk_commissariats_province` FOREIGN KEY (`id_province`) REFERENCES `provinces` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_commissariats_ville` FOREIGN KEY (`id_ville`) REFERENCES `villes` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_commissariats_commune` FOREIGN KEY (`id_commune`) REFERENCES `communes` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 3. UTILISATEURS  (role porté par le RBAC, plus par une colonne ENUM)
-- =====================================================================

CREATE TABLE `users` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nom` VARCHAR(50) NOT NULL,
  `postnom` VARCHAR(50) NULL,
  `prenom` VARCHAR(50) NULL,
  `email` VARCHAR(100) NOT NULL,
  `telephone` VARCHAR(20) NOT NULL,
  `password` VARCHAR(255) NOT NULL,
  `avatar` VARCHAR(255) NULL,
  `statut` ENUM('actif','inactif','suspendu','bloque') NOT NULL DEFAULT 'actif',
  `adresse` VARCHAR(255) NULL,
  `date_naissance` DATE NULL,
  `genre` ENUM('M','F','Autre') NULL,
  `id_commissariat` INT UNSIGNED NULL,
  `matricule_police` VARCHAR(50) NULL,
  `grade_police` VARCHAR(50) NULL,
  `email_verifie` TINYINT(1) NOT NULL DEFAULT 0,
  `telephone_verifie` TINYINT(1) NOT NULL DEFAULT 0,
  `derniere_connexion` DATETIME NULL,
  `last_password_change` DATETIME NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_users_email` (`email`),
  UNIQUE KEY `uk_users_telephone` (`telephone`),
  UNIQUE KEY `uk_users_matricule` (`matricule_police`),
  KEY `idx_users_statut` (`statut`),
  KEY `idx_users_commissariat` (`id_commissariat`),
  KEY `idx_users_nom` (`nom`, `postnom`, `prenom`),
  KEY `idx_users_deleted` (`deleted_at`),
  CONSTRAINT `fk_users_commissariat` FOREIGN KEY (`id_commissariat`) REFERENCES `commissariats` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- FK différée : responsable de commissariat (évite le cycle)
ALTER TABLE `commissariats`
  ADD CONSTRAINT `fk_commissariats_responsable`
  FOREIGN KEY (`responsable_id`) REFERENCES `users` (`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

-- =====================================================================
-- 4. RÔLES ET PERMISSIONS (RBAC) — source unique des droits
-- =====================================================================

CREATE TABLE `roles` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nom` VARCHAR(100) NOT NULL,
  `description` TEXT NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_roles_nom` (`nom`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `permissions` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(100) NOT NULL,
  `description` TEXT NULL,
  `module` VARCHAR(50) NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_permissions_code` (`code`),
  KEY `idx_permissions_module` (`module`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `user_role` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` INT UNSIGNED NOT NULL,
  `role_id` INT UNSIGNED NOT NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_role` (`user_id`, `role_id`),
  KEY `idx_user_role_role` (`role_id`),
  CONSTRAINT `fk_user_role_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_user_role_role` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `role_permission` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `role_id` INT UNSIGNED NOT NULL,
  `permission_id` INT UNSIGNED NOT NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_role_permission` (`role_id`, `permission_id`),
  KEY `idx_role_permission_permission` (`permission_id`),
  CONSTRAINT `fk_role_permission_role` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_role_permission_permission` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 5. JETONS DE VÉRIFICATION + RÉVOCATION
-- =====================================================================

CREATE TABLE `verification_tokens` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_user` INT UNSIGNED NOT NULL,
  `type` ENUM('email','telephone','password_reset') NOT NULL,
  `code` VARCHAR(10) NULL,
  `jeton_hash` CHAR(64) NOT NULL,
  `tentatives` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `expire_at` DATETIME NOT NULL,
  `utilise_le` DATETIME NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_vtokens_hash` (`jeton_hash`),
  KEY `idx_vtokens_user_type` (`id_user`, `type`),
  KEY `idx_vtokens_expire` (`expire_at`),
  CONSTRAINT `fk_vtokens_user` FOREIGN KEY (`id_user`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `token_denylist` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `jti` CHAR(36) NOT NULL,
  `id_user` INT UNSIGNED NULL,
  `expire_at` DATETIME NOT NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_denylist_jti` (`jti`),
  KEY `idx_denylist_expire` (`expire_at`),
  KEY `idx_denylist_user` (`id_user`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 6. TYPES D'ALERTES
-- =====================================================================

CREATE TABLE `typealertes` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(30) NOT NULL,
  `contenu` VARCHAR(150) NOT NULL,
  `niveau_urgence_defaut` ENUM('faible','moyen','eleve','critique') NOT NULL DEFAULT 'moyen',
  `necessite_police` TINYINT(1) NOT NULL DEFAULT 1,
  `icone` VARCHAR(100) NULL,
  `statut` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_typealertes_code` (`code`),
  KEY `idx_typealertes_statut` (`statut`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 7. ALERTES
-- =====================================================================

CREATE TABLE `alertes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `reference` VARCHAR(50) NOT NULL,
  `id_user` INT UNSIGNED NOT NULL,
  `id_type_alerte` INT UNSIGNED NOT NULL,
  `contenu` TEXT NOT NULL,
  `niveau_urgence` ENUM('faible','moyen','eleve','critique') NOT NULL DEFAULT 'moyen',
  `statut` ENUM('nouvelle','prise_en_compte','en_cours','resolue','classee','fausse_alerte') NOT NULL DEFAULT 'nouvelle',
  `id_commissariat` INT UNSIGNED NULL,
  `id_policier_assignee` INT UNSIGNED NULL,
  `latitude` DECIMAL(10,7) NULL,
  `longitude` DECIMAL(10,7) NULL,
  `adresse_precise` VARCHAR(255) NULL,
  `date_alerte` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_prise_en_compte` DATETIME NULL,
  `date_resolution` DATETIME NULL,
  `observation` TEXT NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_alertes_reference` (`reference`),
  KEY `idx_alertes_user` (`id_user`),
  KEY `idx_alertes_type` (`id_type_alerte`),
  KEY `idx_alertes_urgence` (`niveau_urgence`),
  KEY `idx_alertes_commissariat` (`id_commissariat`),
  KEY `idx_alertes_policier` (`id_policier_assignee`),
  KEY `idx_alertes_date` (`date_alerte`),
  KEY `idx_alertes_geo` (`latitude`, `longitude`),
  KEY `idx_alertes_file` (`id_commissariat`, `statut`, `date_alerte`),
  KEY `idx_alertes_priorite` (`statut`, `niveau_urgence`, `date_alerte`),
  CONSTRAINT `fk_alertes_user` FOREIGN KEY (`id_user`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_alertes_type` FOREIGN KEY (`id_type_alerte`) REFERENCES `typealertes` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_alertes_commissariat` FOREIGN KEY (`id_commissariat`) REFERENCES `commissariats` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_alertes_policier` FOREIGN KEY (`id_policier_assignee`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `chk_alertes_dates` CHECK (
    (`date_prise_en_compte` IS NULL OR `date_prise_en_compte` >= `date_alerte`)
    AND (`date_resolution` IS NULL OR `date_resolution` >= `date_alerte`)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 8. CAS (dossiers d'enlèvement, vol, agression…)
-- =====================================================================

CREATE TABLE `cas` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `numero_dossier` VARCHAR(50) NOT NULL,
  `id_alerte` BIGINT UNSIGNED NULL,
  `type_cas` ENUM('enlevement','vol_vehicule','vol_objet','agression','disparition','autre') NOT NULL,
  `id_victime` INT UNSIGNED NULL,
  `description` TEXT NOT NULL,
  `lieu` VARCHAR(255) NULL,
  `latitude` DECIMAL(10,7) NULL,
  `longitude` DECIMAL(10,7) NULL,
  `date_faits` DATETIME NOT NULL,
  `date_ouverture` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_cloture` DATETIME NULL,
  `statut` ENUM('ouvert','en_cours','en_attente','clos','classe') NOT NULL DEFAULT 'ouvert',
  `priorite` ENUM('basse','normale','haute','critique') NOT NULL DEFAULT 'normale',
  `id_commissariat` INT UNSIGNED NOT NULL,
  `id_enqueteur_principal` INT UNSIGNED NULL,
  `resultat` TEXT NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_cas_numero` (`numero_dossier`),
  KEY `idx_cas_alerte` (`id_alerte`),
  KEY `idx_cas_type` (`type_cas`),
  KEY `idx_cas_statut` (`statut`),
  KEY `idx_cas_priorite` (`priorite`),
  KEY `idx_cas_commissariat` (`id_commissariat`),
  KEY `idx_cas_enqueteur` (`id_enqueteur_principal`),
  KEY `idx_cas_victime` (`id_victime`),
  KEY `idx_cas_date_faits` (`date_faits`),
  KEY `idx_cas_date_ouverture` (`date_ouverture`),
  KEY `idx_cas_file` (`id_commissariat`, `statut`, `priorite`),
  CONSTRAINT `fk_cas_alerte` FOREIGN KEY (`id_alerte`) REFERENCES `alertes` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_cas_victime` FOREIGN KEY (`id_victime`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_cas_commissariat` FOREIGN KEY (`id_commissariat`) REFERENCES `commissariats` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_cas_enqueteur` FOREIGN KEY (`id_enqueteur_principal`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `chk_cas_dates` CHECK (
    `date_ouverture` >= `date_faits`
    AND (`date_cloture` IS NULL OR `date_cloture` >= `date_ouverture`)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 9. INTERVENTIONS POLICIÈRES
-- =====================================================================

CREATE TABLE `interventions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_cas` BIGINT UNSIGNED NOT NULL,
  `id_policier` INT UNSIGNED NOT NULL,
  `type_intervention` ENUM('patrouille','perquisition','audition','arrestation','perquisition_domicile','convocation','autre') NOT NULL,
  `description` TEXT NOT NULL,
  `date_intervention` DATETIME NOT NULL,
  `duree_minutes` INT NULL,
  `lieu` VARCHAR(255) NULL,
  `resultat` TEXT NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_interventions_cas` (`id_cas`),
  KEY `idx_interventions_policier` (`id_policier`),
  KEY `idx_interventions_type` (`type_intervention`),
  KEY `idx_interventions_date` (`date_intervention`),
  KEY `idx_interventions_cas_date` (`id_cas`, `date_intervention`),
  CONSTRAINT `fk_interventions_cas` FOREIGN KEY (`id_cas`) REFERENCES `cas` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_interventions_policier` FOREIGN KEY (`id_policier`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 10. TYPES D'OBJETS ET OBJETS VOLÉS
-- =====================================================================

CREATE TABLE `type_objets` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(30) NOT NULL,
  `description` VARCHAR(150) NOT NULL,
  `icone` VARCHAR(100) NULL,
  `statut` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_type_objets_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `objets` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_type` INT UNSIGNED NOT NULL,
  `id_user_proprietaire` INT UNSIGNED NOT NULL,
  `marque` VARCHAR(100) NULL,
  `model` VARCHAR(100) NULL,
  `numero_chassis` VARCHAR(100) NULL,
  `immatriculation` VARCHAR(50) NULL,
  `numero_serie` VARCHAR(100) NULL,
  `couleur` VARCHAR(50) NULL,
  `description` TEXT NULL,
  `date_vol` DATETIME NULL,
  `lieu_vol` VARCHAR(255) NULL,
  `latitude_vol` DECIMAL(10,7) NULL,
  `longitude_vol` DECIMAL(10,7) NULL,
  `statut` ENUM('declare_vol','recherche','retrouve','restitue','en_fourriere','classe','en_possession') NOT NULL DEFAULT 'declare_vol',
  `id_cas` BIGINT UNSIGNED NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  KEY `idx_objets_type` (`id_type`),
  KEY `idx_objets_proprietaire` (`id_user_proprietaire`),
  KEY `idx_objets_statut` (`statut`),
  KEY `idx_objets_chassis` (`numero_chassis`),
  KEY `idx_objets_immat` (`immatriculation`),
  KEY `idx_objets_serie` (`numero_serie`),
  KEY `idx_objets_cas` (`id_cas`),
  KEY `idx_objets_date_vol` (`date_vol`),
  KEY `idx_objets_recherche` (`statut`, `date_vol`),
  CONSTRAINT `fk_objets_type` FOREIGN KEY (`id_type`) REFERENCES `type_objets` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_objets_proprietaire` FOREIGN KEY (`id_user_proprietaire`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_objets_cas` FOREIGN KEY (`id_cas`) REFERENCES `cas` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------
-- 10bis. PARTAGES D'OBJETS (images transmises à la police et aux amis)
-- ----------------------------------------------------------------------

CREATE TABLE `partages` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_objet` INT UNSIGNED NOT NULL,
  `id_proprietaire` INT UNSIGNED NOT NULL,
  `id_destinataire` INT UNSIGNED NOT NULL,
  `message` VARCHAR(500) NULL,
  `lu` TINYINT(1) NOT NULL DEFAULT 0,
  `date_partage` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_partage_objet_destinataire` (`id_objet`, `id_destinataire`),
  KEY `idx_partages_destinataire` (`id_destinataire`, `lu`),
  KEY `idx_partages_objet` (`id_objet`),
  KEY `idx_partages_date` (`date_partage`),
  CONSTRAINT `fk_partages_objet` FOREIGN KEY (`id_objet`) REFERENCES `objets` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_partages_proprietaire` FOREIGN KEY (`id_proprietaire`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_partages_destinataire` FOREIGN KEY (`id_destinataire`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 11. PREUVES (photos, vidéos, documents)
-- =====================================================================

CREATE TABLE `preuves` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `entite_type` ENUM('cas','alerte','objet','intervention') NOT NULL,
  `entite_id` BIGINT UNSIGNED NOT NULL,
  `type_preuve` ENUM('photo','video','audio','document','autre') NOT NULL,
  `nom_original` VARCHAR(255) NOT NULL,
  `nom_stocke` VARCHAR(255) NOT NULL,
  `extension` VARCHAR(10) NOT NULL,
  `type_mime` VARCHAR(100) NOT NULL,
  `taille_octets` BIGINT UNSIGNED NOT NULL,
  `chemin_stockage` VARCHAR(500) NOT NULL,
  `hash_sha256` CHAR(64) NULL,
  `description` TEXT NULL,
  `id_user_upload` INT UNSIGNED NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` DATETIME NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_preuves_nom_stocke` (`nom_stocke`),
  KEY `idx_preuves_entite` (`entite_type`, `entite_id`),
  KEY `idx_preuves_type` (`type_preuve`),
  KEY `idx_preuves_hash` (`hash_sha256`),
  KEY `idx_preuves_upload` (`id_user_upload`),
  CONSTRAINT `fk_preuves_user` FOREIGN KEY (`id_user_upload`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 12. LOCALISATIONS
-- =====================================================================

CREATE TABLE `localisations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_user` INT UNSIGNED NOT NULL,
  `latitude` DECIMAL(10,7) NOT NULL,
  `longitude` DECIMAL(10,7) NOT NULL,
  `latitude_delta` DECIMAL(10,7) NULL,
  `longitude_delta` DECIMAL(10,7) NULL,
  `precision_metres` DECIMAL(8,2) NULL,
  `source` ENUM('gps','reseau','manuel') NOT NULL DEFAULT 'gps',
  `date_localisation` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_loc_user_date` (`id_user`, `date_localisation`),
  KEY `idx_loc_date` (`date_localisation`),
  KEY `idx_loc_geo` (`latitude`, `longitude`),
  CONSTRAINT `fk_loc_user` FOREIGN KEY (`id_user`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 13. DEMANDES D'AMIS
-- =====================================================================

CREATE TABLE `demandes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `recev_id` INT UNSIGNED NOT NULL,
  `envoi_id` INT UNSIGNED NOT NULL,
  `date_demande` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `statut` ENUM('en_attente','acceptee','refusee','annulee') NOT NULL DEFAULT 'en_attente',
  `date_reponse` DATETIME NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  -- Colonne maintenue par trigger : MySQL refuse toute FK sur une table
  -- contenant une colonne GENERATED (erreur 1215).
  `cle_paire` VARCHAR(23) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_demandes_paire_statut` (`cle_paire`, `statut`),
  KEY `idx_demandes_recev_statut` (`recev_id`, `statut`),
  KEY `idx_demandes_envoi_statut` (`envoi_id`, `statut`),
  KEY `idx_demandes_date` (`date_demande`),
  CONSTRAINT `fk_demandes_recev` FOREIGN KEY (`recev_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_demandes_envoi` FOREIGN KEY (`envoi_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- CHECK impossible ici (colonnes sous ON DELETE/UPDATE CASCADE) : on passe par des triggers.
-- Les triggers calculent aussi `cle_paire` (clé de couple non ordonnée), ce qui interdit
-- d'avoir simultanément A->B et B->A pour un même statut.
DELIMITER $$
CREATE TRIGGER `trg_demandes_bi` BEFORE INSERT ON `demandes` FOR EACH ROW
BEGIN
  IF NEW.`recev_id` = NEW.`envoi_id` THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Une demande d ami ne peut pas partir vers soi-même';
  END IF;
  SET NEW.`cle_paire` = CONCAT(LEAST(NEW.`recev_id`, NEW.`envoi_id`), '-',
                               GREATEST(NEW.`recev_id`, NEW.`envoi_id`));
END$$
CREATE TRIGGER `trg_demandes_bu` BEFORE UPDATE ON `demandes` FOR EACH ROW
BEGIN
  IF NEW.`recev_id` = NEW.`envoi_id` THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Une demande d ami ne peut pas partir vers soi-même';
  END IF;
  SET NEW.`cle_paire` = CONCAT(LEAST(NEW.`recev_id`, NEW.`envoi_id`), '-',
                               GREATEST(NEW.`recev_id`, NEW.`envoi_id`));
END$$
DELIMITER ;

-- =====================================================================
-- 14. MESSAGES PRIVÉS
-- =====================================================================

CREATE TABLE `notes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_rec` INT UNSIGNED NOT NULL,
  `id_sender` INT UNSIGNED NOT NULL,
  `messages` TEXT NOT NULL,
  `lu` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_notes_rec_lu` (`id_rec`, `lu`),
  KEY `idx_notes_conversation` (`id_sender`, `id_rec`, `created_at`),
  CONSTRAINT `fk_notes_rec` FOREIGN KEY (`id_rec`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_notes_sender` FOREIGN KEY (`id_sender`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELIMITER $$
CREATE TRIGGER `trg_notes_no_self_ins` BEFORE INSERT ON `notes` FOR EACH ROW
BEGIN
  IF NEW.`id_rec` = NEW.`id_sender` THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un message ne peut pas être envoyé à soi-même';
  END IF;
END$$
CREATE TRIGGER `trg_notes_no_self_upd` BEFORE UPDATE ON `notes` FOR EACH ROW
BEGIN
  IF NEW.`id_rec` = NEW.`id_sender` THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un message ne peut pas être envoyé à soi-même';
  END IF;
END$$
DELIMITER ;

-- =====================================================================
-- 15. NOTIFICATIONS (remplace mesnotification + notifications de la v1)
-- =====================================================================

CREATE TABLE `notifications` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_user` INT UNSIGNED NOT NULL,
  `id_sender` INT UNSIGNED NULL,
  `type` ENUM('systeme','demande_ami','message','alerte_creee','alerte_assignee','alerte_resolue','cas_maj','preuve_ajoutee','objet_retrouve','partage') NOT NULL DEFAULT 'systeme',
  `titre` VARCHAR(150) NOT NULL,
  `message` TEXT NOT NULL,
  `entite_type` ENUM('alerte','cas','objet','intervention','demande','preuve','user') NULL,
  `entite_id` BIGINT UNSIGNED NULL,
  `lien` VARCHAR(255) NULL,
  `lu` TINYINT(1) NOT NULL DEFAULT 0,
  `date_envoi` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `date_lecture` DATETIME NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_notif_user_lu` (`id_user`, `lu`),
  KEY `idx_notif_user_date` (`id_user`, `date_envoi`),
  KEY `idx_notif_entite` (`entite_type`, `entite_id`),
  KEY `idx_notif_type` (`type`),
  CONSTRAINT `fk_notif_user` FOREIGN KEY (`id_user`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_notif_sender` FOREIGN KEY (`id_sender`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 16. JOURNALISATION / AUDIT
-- =====================================================================

CREATE TABLE `audit_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` INT UNSIGNED NULL,
  `action` VARCHAR(50) NOT NULL,
  `entite` VARCHAR(100) NOT NULL,
  `entite_id` BIGINT UNSIGNED NULL,
  `description` TEXT NULL,
  `valeurs_avant` JSON NULL,
  `valeurs_apres` JSON NULL,
  `ip_address` VARCHAR(45) NULL,
  `user_agent` VARCHAR(500) NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_audit_user` (`user_id`),
  KEY `idx_audit_entite` (`entite`, `entite_id`),
  KEY `idx_audit_action` (`action`),
  KEY `idx_audit_date` (`created_at`),
  CONSTRAINT `fk_audit_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- 17. VUES
-- =====================================================================

-- Amis acceptés, dans les DEUX sens. Filtrer par utilisateur côté applicatif :
--   ... FROM v_amis_acceptes WHERE id_utilisateur = :moi
CREATE OR REPLACE VIEW `v_amis_acceptes` AS
SELECT
  d.id AS id_demande,
  d.recev_id AS id_utilisateur,
  d.envoi_id AS id_ami,
  u.nom, u.postnom, u.prenom, u.email, u.avatar, u.telephone,
  d.date_reponse
FROM `demandes` d
JOIN `users` u ON u.id = d.envoi_id
WHERE d.statut = 'acceptee'
UNION ALL
SELECT
  d.id AS id_demande,
  d.envoi_id AS id_utilisateur,
  d.recev_id AS id_ami,
  u.nom, u.postnom, u.prenom, u.email, u.avatar, u.telephone,
  d.date_reponse
FROM `demandes` d
JOIN `users` u ON u.id = d.recev_id
WHERE d.statut = 'acceptee';

-- Rôles agrégés par utilisateur (source unique : RBAC)
CREATE OR REPLACE VIEW `v_users_roles` AS
SELECT
  u.id,
  u.nom, u.postnom, u.prenom, u.email, u.telephone,
  u.statut, u.id_commissariat, u.matricule_police, u.grade_police,
  u.deleted_at,
  COALESCE(GROUP_CONCAT(r.nom ORDER BY r.nom SEPARATOR ','), '') AS roles
FROM `users` u
LEFT JOIN `user_role` ur ON ur.user_id = u.id
LEFT JOIN `roles` r ON r.id = ur.role_id
GROUP BY u.id, u.nom, u.postnom, u.prenom, u.email, u.telephone,
         u.statut, u.id_commissariat, u.matricule_police, u.grade_police, u.deleted_at;

-- Dernière position connue de chaque utilisateur
CREATE OR REPLACE VIEW `v_dernieres_positions` AS
SELECT l.id_user, l.latitude, l.longitude, l.precision_metres,
       l.source, l.date_localisation
FROM `localisations` l
JOIN (
  SELECT id_user, MAX(date_localisation) AS dmax
  FROM `localisations`
  GROUP BY id_user
) m ON m.id_user = l.id_user AND m.dmax = l.date_localisation;

-- Alertes enrichies
CREATE OR REPLACE VIEW `v_alertes_detail` AS
SELECT
  a.id, a.reference, a.contenu, a.niveau_urgence, a.statut,
  a.latitude, a.longitude, a.adresse_precise, a.date_alerte,
  a.date_prise_en_compte, a.date_resolution,
  t.code AS type_code, t.contenu AS type_libelle, t.necessite_police,
  u.id AS id_emetteur, u.nom AS emetteur_nom, u.prenom AS emetteur_prenom,
  u.telephone AS emetteur_tel,
  c.nom AS commissariat_nom,
  p.nom AS policier_nom, p.prenom AS policier_prenom
FROM `alertes` a
JOIN `typealertes` t ON t.id = a.id_type_alerte
JOIN `users` u ON u.id = a.id_user
LEFT JOIN `commissariats` c ON c.id = a.id_commissariat
LEFT JOIN `users` p ON p.id = a.id_policier_assignee
WHERE a.deleted_at IS NULL;

-- Cas avec informations agrégées
CREATE OR REPLACE VIEW `v_cas_detail` AS
SELECT
  c.id, c.numero_dossier, c.type_cas, c.statut, c.priorite,
  c.date_faits, c.date_ouverture, c.date_cloture,
  c.lieu, c.description,
  v.id AS id_victime, v.nom AS victime_nom, v.prenom AS victime_prenom,
  v.telephone AS victime_tel,
  com.nom AS commissariat_nom,
  e.nom AS enqueteur_nom, e.prenom AS enqueteur_prenom,
  (SELECT COUNT(*) FROM `interventions` i WHERE i.id_cas = c.id) AS nb_interventions,
  (SELECT COUNT(*) FROM `preuves` pr
     WHERE pr.entite_type = 'cas' AND pr.entite_id = c.id AND pr.deleted_at IS NULL) AS nb_preuves
FROM `cas` c
LEFT JOIN `users` v ON v.id = c.id_victime
LEFT JOIN `commissariats` com ON com.id = c.id_commissariat
LEFT JOIN `users` e ON e.id = c.id_enqueteur_principal
WHERE c.deleted_at IS NULL;

-- Objets volés avec type
CREATE OR REPLACE VIEW `v_objets_detail` AS
SELECT
  o.id, o.marque, o.model, o.numero_chassis, o.immatriculation, o.numero_serie,
  o.couleur, o.statut, o.date_vol, o.lieu_vol, o.latitude_vol, o.longitude_vol,
  t.code AS type_code, t.description AS type_libelle,
  u.id AS id_proprietaire, u.nom AS proprietaire_nom,
  u.prenom AS proprietaire_prenom, u.telephone AS proprietaire_tel,
  o.id_cas
FROM `objets` o
JOIN `type_objets` t ON t.id = o.id_type
JOIN `users` u ON u.id = o.id_user_proprietaire
WHERE o.deleted_at IS NULL;

-- =====================================================================
-- 18. DONNÉES DE RÉFÉRENCE
-- =====================================================================

-- 18.1 Les 26 provinces de la RDC (chefs-lieux officiels)
INSERT INTO `provinces` (`code`, `nom`, `chef_lieu`) VALUES
  ('BUE','Bas-Uele','Buta'),
  ('EQU','Équateur','Mbandaka'),
  ('HKT','Haut-Katanga','Lubumbashi'),
  ('HLM','Haut-Lomami','Kamina'),
  ('HUE','Haut-Uele','Isiro'),
  ('ITU','Ituri','Bunia'),
  ('KSA','Kasaï','Tshikapa'),
  ('KSC','Kasaï-Central','Kananga'),
  ('KSO','Kasaï-Oriental','Mbujimayi'),
  ('KIN','Kinshasa','Kinshasa'),
  ('KCS','Kongo-Central','Matadi'),
  ('KWG','Kwango','Kenge'),
  ('KWL','Kwilu','Bandundu'),
  ('LOM','Lomami','Kabinda'),
  ('LUA','Lualaba','Kolwezi'),
  ('MND','Mai-Ndombe','Inongo'),
  ('MAN','Maniema','Kindu'),
  ('MON','Mongala','Lisala'),
  ('NKI','Nord-Kivu','Goma'),
  ('NUB','Nord-Ubangi','Gbadolite'),
  ('SAN','Sankuru','Lusambo'),
  ('SKI','Sud-Kivu','Bukavu'),
  ('SUB','Sud-Ubangi','Gemena'),
  ('TAN','Tanganyika','Kalemie'),
  ('TSH','Tshopo','Kisangani'),
  ('TSP','Tshuapa','Boende');

-- 18.2 Villes : un chef-lieu par province + quelques villes importantes
INSERT INTO `villes` (`id_province`, `nom`, `latitude`, `longitude`)
SELECT p.id, p.chef_lieu, NULL, NULL FROM `provinces` p WHERE p.chef_lieu IS NOT NULL;

INSERT INTO `villes` (`id_province`, `nom`, `latitude`, `longitude`)
SELECT p.id, v.ville_nom, v.lat, v.lon FROM (
  SELECT 'KWL' AS pc, 'Kikwit' AS ville_nom, -5.0380000 AS lat, 20.8590000 AS lon UNION ALL
  SELECT 'HKT', 'Likasi', -10.9833333, 26.7333333 UNION ALL
  SELECT 'HKT', 'Kipushi', -11.7666667, 27.2500000 UNION ALL
  SELECT 'LUA', 'Likasi', -10.9833333, 26.7333333 UNION ALL
  SELECT 'NKI', 'Sake', -1.6166667, 29.3333333 UNION ALL
  SELECT 'SKI', 'Uvira', -3.3733333, 29.1400000 UNION ALL
  SELECT 'KCS', 'Boma', -5.8500000, 13.0500000 UNION ALL
  SELECT 'KCS', 'Kasangulu', -4.4783333, 15.1333333 UNION ALL
  SELECT 'KSA', 'Luebo', -5.3500000, 21.4166667 UNION ALL
  SELECT 'ITU', 'Bunia', 1.5666667, 30.2500000 UNION ALL
  SELECT 'EQU', 'Mbandaka', 0.0500000, 18.2500000
) v
JOIN `provinces` p ON p.code = v.pc
ON DUPLICATE KEY UPDATE `latitude` = IFNULL(VALUES(`latitude`), `latitude`);

-- 18.3 Commissariats (jeu de test : Kinshasa + principales villes)
INSERT INTO `commissariats`
  (`code`, `nom`, `id_province`, `id_ville`, `adresse`, `telephone`, `email`, `latitude`, `longitude`, `statut`)
SELECT 'COM-KIN-001', 'Commissariat Central de Kinshasa / Gombe', p.id, v.id,
       'Av. de la Justice, Gombe, Kinshasa', '+243 81 000 0001', 'kin1@police.cd', -4.3250000, 15.3100000, 1
FROM `provinces` p JOIN `villes` v ON v.id_province = p.id AND v.nom = 'Kinshasa'
UNION ALL
SELECT 'COM-KIN-002', 'Commissariat de Ngaliema', p.id, v.id,
       'Av. Kikwit, Ngaliema, Kinshasa', '+243 81 000 0002', 'kin2@police.cd', -4.4347000, 15.2466000, 1
FROM `provinces` p JOIN `villes` v ON v.id_province = p.id AND v.nom = 'Kinshasa'
UNION ALL
SELECT 'COM-KIN-003', 'Commissariat de Masina', p.id, v.id,
       'Av. de l’Aéroport, Masina, Kinshasa', '+243 81 000 0003', 'kin3@police.cd', -4.3417000, 15.4233333, 1
FROM `provinces` p JOIN `villes` v ON v.id_province = p.id AND v.nom = 'Kinshasa'
UNION ALL
SELECT 'COM-KIN-004', 'Commissariat de Limete', p.id, v.id,
       'Av. Général Mobutu, Limete, Kinshasa', '+243 81 000 0004', 'kin4@police.cd', -4.3276000, 15.3444000, 1
FROM `provinces` p JOIN `villes` v ON v.id_province = p.id AND v.nom = 'Kinshasa'
UNION ALL
SELECT 'COM-LUB-001', 'Commissariat Central de Lubumbashi', p.id, v.id,
       'Av. sentier, Lubumbashi', '+243 82 000 0001', 'lub1@police.cd', -11.6600000, 27.4800000, 1
FROM `provinces` p JOIN `villes` v ON v.id_province = p.id AND v.nom = 'Lubumbashi'
UNION ALL
SELECT 'COM-GOM-001', 'Commissariat Central de Goma', p.id, v.id,
       'Av. Kanyamuhanga, Goma', '+243 83 000 0001', 'gom1@police.cd', -1.6800000, 29.2300000, 1
FROM `provinces` p JOIN `villes` v ON v.id_province = p.id AND v.nom = 'Goma'
UNION ALL
SELECT 'COM-BUK-001', 'Commissariat Central de Bukavu', p.id, v.id,
       'Av. Muhabura, Bukavu', '+243 84 000 0001', 'buk1@police.cd', -2.5100000, 28.8600000, 1
FROM `provinces` p JOIN `villes` v ON v.id_province = p.id AND v.nom = 'Bukavu'
UNION ALL
SELECT 'COM-MBU-001', 'Commissariat Central de Mbujimayi', p.id, v.id,
       'Av. Kasavubu, Mbujimayi', '+243 85 000 0001', 'mbu1@police.cd', -2.9800000, 23.7800000, 1
FROM `provinces` p JOIN `villes` v ON v.id_province = p.id AND v.nom = 'Mbujimayi'
UNION ALL
SELECT 'COM-KAN-001', 'Commissariat Central de Kananga', p.id, v.id,
       'Av. de la Paix, Kananga', '+243 86 000 0001', 'kan1@police.cd', -5.8950000, 22.4030000, 1
FROM `provinces` p JOIN `villes` v ON v.id_province = p.id AND v.nom = 'Kananga'
UNION ALL
SELECT 'COM-KIS-001', 'Commissariat Central de Kisangani', p.id, v.id,
       'Av. de la Libération, Kisangani', '+243 87 000 0001', 'kis1@police.cd', 0.5166667, 25.1833333, 1
FROM `provinces` p JOIN `villes` v ON v.id_province = p.id AND v.nom = 'Kisangani';

-- 18.3bis Communes de la ville de Kinshasa (24 communes officielles)
INSERT INTO `communes` (`id_ville`, `nom`)
SELECT v.id, n.nom
FROM `villes` v
JOIN `provinces` p ON p.id = v.id_province AND p.code = 'KIN'
JOIN (
  SELECT 'Bandalungwa' AS nom UNION ALL SELECT 'Barumbu' UNION ALL
  SELECT 'Bumbu' UNION ALL SELECT 'Gombe' UNION ALL SELECT 'Kalamu' UNION ALL
  SELECT 'Kasa-Vubu' UNION ALL SELECT 'Kimbanseke' UNION ALL
  SELECT 'Kinshasa' UNION ALL SELECT 'Kintambo' UNION ALL SELECT 'Kisenso' UNION ALL
  SELECT 'Lemba' UNION ALL SELECT 'Limete' UNION ALL SELECT 'Lingwala' UNION ALL
  SELECT 'Makala' UNION ALL SELECT 'Maluku' UNION ALL SELECT 'Masina' UNION ALL
  SELECT 'Matete' UNION ALL SELECT 'Mont-Ngafula' UNION ALL SELECT 'Ndjili' UNION ALL
  SELECT 'Ngaba' UNION ALL SELECT 'Ngaliema' UNION ALL SELECT 'Ngiri-Ngiri' UNION ALL
  SELECT 'Selembao' UNION ALL SELECT 'Wasa-Ndako'
) n
WHERE v.nom = 'Kinshasa'
ON DUPLICATE KEY UPDATE `nom` = VALUES(`nom`);

-- 18.3ter Rattachement des commissariats de Kinshasa à leur commune
UPDATE `commissariats` c
  JOIN `communes` m ON m.nom = CASE c.`code`
        WHEN 'COM-KIN-001' THEN 'Gombe'
        WHEN 'COM-KIN-002' THEN 'Ngaliema'
        WHEN 'COM-KIN-003' THEN 'Masina'
        WHEN 'COM-KIN-004' THEN 'Limete'
      END
   SET c.`id_commune` = m.`id`
 WHERE c.`code` IN ('COM-KIN-001','COM-KIN-002','COM-KIN-003','COM-KIN-004');

-- 18.4 Rôles
INSERT INTO `roles` (`nom`, `description`) VALUES
  ('citoyen',    'Utilisateur civil : déclenche des alertes, suit ses dossiers.'),
  ('policier',   'Agent de police : file d''attente des alertes, interventions.'),
  ('enqueteur',  'Enquêteur : ouverture et instruction des dossiers (cas).'),
  ('admin',      'Administrateur opérationnel : gestion des comptes et des commissariats.'),
  ('super_admin','Administrateur technique : RBAC, audit, paramétrage global.');

-- 18.5 Permissions
INSERT INTO `permissions` (`code`, `module`, `description`) VALUES
  ('alertes.creer',     'alertes',      'Créer une alerte (citoyen)'),
  ('alertes.lire',      'alertes',      'Consulter les alertes de son périmètre'),
  ('alertes.assigner',  'alertes',      'Assigner une alerte à un policier'),
  ('alertes.traiter',   'alertes',      'Changer le statut d''une alerte'),
  ('alertes.supprimer', 'alertes',      'Supprimer (purge) une alerte'),
  ('cas.creer',         'cas',          'Ouvrir un dossier'),
  ('cas.lire',          'cas',          'Consulter les dossiers du commissariat'),
  ('cas.maj',           'cas',          'Modifier un dossier'),
  ('cas.cloturer',      'cas',          'Clôturer / classer un dossier'),
  ('cas.supprimer',     'cas',          'Supprimer (purge) un dossier'),
  ('interventions.creer','interventions','Enregistrer une intervention'),
  ('interventions.lire', 'interventions','Consulter les interventions'),
  ('interventions.maj',  'interventions','Modifier une intervention'),
  ('preuves.creer',     'preuves',      'Téléverser une preuve'),
  ('preuves.lire',      'preuves',      'Consulter les preuves autorisées'),
  ('preuves.telecharger','preuves',     'Télécharger une preuve'),
  ('preuves.supprimer', 'preuves',      'Supprimer une preuve'),
  ('objets.creer',      'objets',       'Déclarer un objet volé'),
  ('objets.lire',       'objets',       'Consulter le fichier des objets volés'),
  ('objets.maj',        'objets',       'Mettre à jour le statut d''un objet'),
  ('objets.supprimer',  'objets',       'Supprimer (purge) un objet'),
  ('users.lire',        'users',        'Consulter les fiches utilisateurs'),
  ('users.creer',       'users',        'Créer un compte'),
  ('users.maj',         'users',        'Modifier un compte (son profil ou un autre)'),
  ('users.suspendre',   'users',        'Suspendre / bloquer un compte'),
  ('users.supprimer',   'users',        'Supprimer (purge) un compte'),
  ('commissariats.lire','commissariats','Consulter les commissariats'),
  ('commissariats.gerer','commissariats','Gérer les commissariats'),
  ('geo.lire',          'geo',          'Consulter les localisations'),
  ('geo.proximite',     'geo',          'Recherche par proximité (alertes/commissariats)'),
  ('geo.gerer',         'geo',          'Gérer les référentiels géographiques (provinces, villes, communes, commissariats)'),
  ('social.amis',       'social',       'Demander / répondre aux demandes d''amis'),
  ('social.messages',   'social',       'Envoyer / lire des messages'),
  ('notifications.lire','notifications','Consulter ses notifications'),
  ('notifications.envoyer','notifications','Envoyer une notification'),
  ('audit.lire',        'audit',        'Consulter le journal d''audit'),
  ('rbac.gerer',        'rbac',         'Gérer rôles et permissions');

-- 18.6 Matrice rôle -> permissions
INSERT INTO `role_permission` (`role_id`, `permission_id`)
SELECT r.id, p.id FROM `roles` r JOIN `permissions` p
WHERE r.nom = 'citoyen' AND p.code IN (
  'alertes.creer','alertes.lire','objets.creer','objets.lire','objets.maj',
  'preuves.creer','preuves.lire','preuves.telecharger','preuves.supprimer',
  'users.maj',
  'cas.lire',
  'commissariats.lire','geo.proximite',
  'social.amis','social.messages','notifications.lire'
);

INSERT INTO `role_permission` (`role_id`, `permission_id`)
SELECT r.id, p.id FROM `roles` r JOIN `permissions` p
WHERE r.nom = 'policier' AND p.code IN (
  'alertes.creer',
  'alertes.lire','alertes.assigner','alertes.traiter',
  'cas.lire','interventions.creer','interventions.lire','interventions.maj',
  'preuves.lire','preuves.creer','preuves.telecharger',
  'objets.creer','objets.lire','objets.maj','objets.supprimer','users.lire','users.maj',
  'commissariats.lire','geo.lire','geo.proximite',
  'social.amis','social.messages','notifications.lire','notifications.envoyer'
);

INSERT INTO `role_permission` (`role_id`, `permission_id`)
SELECT r.id, p.id FROM `roles` r JOIN `permissions` p
WHERE r.nom = 'enqueteur' AND p.code IN (
  'alertes.creer',
  'alertes.lire','alertes.assigner','alertes.traiter',
  'cas.creer','cas.lire','cas.maj','cas.cloturer',
  'interventions.creer','interventions.lire','interventions.maj',
  'preuves.creer','preuves.lire','preuves.telecharger','preuves.supprimer',
  'objets.creer','objets.lire','objets.maj','objets.supprimer','objets.supprimer',
  'users.lire','users.maj','commissariats.lire',
  'geo.lire','geo.proximite',
  'social.amis','social.messages','notifications.lire','notifications.envoyer'
);

INSERT INTO `role_permission` (`role_id`, `permission_id`)
SELECT r.id, p.id FROM `roles` r JOIN `permissions` p
WHERE r.nom = 'admin';

INSERT INTO `role_permission` (`role_id`, `permission_id`)
SELECT r.id, p.id FROM `roles` r JOIN `permissions` p
WHERE r.nom = 'super_admin';

-- 18.7 Types d'alertes
INSERT INTO `typealertes`
  (`code`, `contenu`, `niveau_urgence_defaut`, `necessite_police`, `icone`, `statut`)
VALUES
  ('DANGER',            'Je suis en danger',                                  'critique', 1, 'exclamation-triangle', 1),
  ('HOSPITALISATION',   'Je suis hospitalisé',                                'moyen',    0, 'hospital',             1),
  ('CLASSE',            'Je suis en classe',                                  'faible',   0, 'school',                1),
  ('KULUNA',            'Kuluna m''a attaqué',                                'critique', 1, 'user-secret',           1),
  ('AGRESSION',         'Agression à main armée',                             'critique', 1, 'gun',                   1),
  ('ENLEVEMENT',        'Enlèvement / disparition inquiétante',               'critique', 1, 'user-times',            1),
  ('VOL',               'Vol en cours ou récent',                             'eleve',    1, 'mask',                  1),
  ('INCENDIE',          'Incendie / sinistre',                                'critique', 1, 'fire',                  1),
  ('ACCIDENT',          'Accident de la voie publique',                       'eleve',    1, 'car-crash',             1),
  ('VIOLENCE_FEMME',    'Violence faite aux femmes',                          'eleve',    1, 'female',                1),
  ('AUTRE',             'Autre situation nécessitant l''intervention police', 'moyen',    1, 'ellipsis-h',            1);

-- 18.8 Types d'objets
INSERT INTO `type_objets` (`code`, `description`, `icone`, `statut`) VALUES
  ('MOTO',       'Moto',        'motorcycle', 1),
  ('VOITURE',    'Voiture',     'car',        1),
  ('ORDINATEUR', 'Ordinateur',  'laptop',     1),
  ('TELEPHONE',  'Téléphone',   'mobile-alt', 1),
  ('VELO',       'Vélo',        'bicycle',    1),
  ('BIJOUX',     'Bijoux',      'ring',       1),
  ('DOCUMENT',   'Document / Pièce', 'file-alt', 1),
  ('ELECTROMENAGER','Électroménager','plug', 1),
  ('AUTRE',      'Autre',       'box',        1);

-- 18.9 Comptes de démarrage (à modifier dès la première connexion)
--     Mot de passe : 12345678  (hash bcrypt, cost 12)
INSERT INTO `users`
  (`nom`, `postnom`, `prenom`, `email`, `telephone`, `password`, `avatar`,
   `statut`, `id_commissariat`, `matricule_police`, `grade_police`,
   `email_verifie`, `telephone_verifie`, `last_password_change`)
SELECT 'ADMIN', 'SYSTEME', 'Super', 'admin@securite.cd', '+243810000000',
       '$2b$12$u8X9bIpkqT52Y/S8U3CZjuI0Lp69j1aOoVKrGe9ENpjP6EjUarRpC',
       NULL, 'actif', NULL, 'ADM-0001', 'Administrateur technique', 1, 1, NOW()
FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM `users` WHERE `email` = 'admin@securite.cd');

-- Rôles du compte admin
INSERT INTO `user_role` (`user_id`, `role_id`)
SELECT u.id, r.id FROM `users` u JOIN `roles` r
WHERE u.email = 'admin@securite.cd' AND r.nom = 'super_admin'
  AND NOT EXISTS (SELECT 1 FROM `user_role` ur WHERE ur.user_id = u.id AND ur.role_id = r.id);

-- =====================================================================
-- 19. FIN
-- =====================================================================

SET FOREIGN_KEY_CHECKS = 1;
