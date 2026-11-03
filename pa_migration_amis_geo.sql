-- Migration PA : amis + geocodage inverse + SOS (a executer UNE fois)
USE sindani$default;

-- 0) Table SOS (compte a rebours serveur) si elle n'existe pas encore
CREATE TABLE IF NOT EXISTS `sos` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_user` INT UNSIGNED NOT NULL,
  `statut` VARCHAR(20) NOT NULL DEFAULT 'programme',
  `duree_minutes` TINYINT UNSIGNED NOT NULL DEFAULT 15,
  `echeance` DATETIME NOT NULL,
  `latitude` DECIMAL(10,7) NULL,
  `longitude` DECIMAL(10,7) NULL,
  `intermediaire_at` DATETIME NULL,
  `envoye_at` DATETIME NULL,
  `cloture_at` DATETIME NULL,
  `id_alerte` BIGINT UNSIGNED NULL,
  `created_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_sos_user_statut` (`id_user`, `statut`),
  KEY `idx_sos_echeance` (`statut`, `echeance`),
  CONSTRAINT `fk_sos_user` FOREIGN KEY (`id_user`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_sos_alerte` FOREIGN KEY (`id_alerte`) REFERENCES `alertes` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 1) Nouveaux types de notification
ALTER TABLE `notifications`
  MODIFY `type` ENUM('systeme','demande_ami','message','alerte_creee','alerte_assignee','alerte_resolue','cas_maj','preuve_ajoutee','objet_retrouve','partage','sos','objet_declare') NOT NULL DEFAULT 'systeme';

-- 2) Coordonnees des villes (geocodage inverse)
UPDATE `villes` SET `latitude` = -4.4419,  `longitude` = 15.2669  WHERE `nom` = 'Kinshasa';
UPDATE `villes` SET `latitude` = -11.6667, `longitude` = 27.4833  WHERE `nom` = 'Lubumbashi';
UPDATE `villes` SET `latitude` = -6.1500,  `longitude` = 23.5833  WHERE `nom` = 'Mbuji-Mayi';
UPDATE `villes` SET `latitude` = 0.5167,   `longitude` = 25.1833  WHERE `nom` = 'Kisangani';
UPDATE `villes` SET `latitude` = -5.8958,  `longitude` = 22.4133  WHERE `nom` = 'Kananga';
UPDATE `villes` SET `latitude` = -2.5167,  `longitude` = 28.8667  WHERE `nom` = 'Bukavu';
UPDATE `villes` SET `latitude` = -1.6583,  `longitude` = 29.2200  WHERE `nom` = 'Goma';
UPDATE `villes` SET `latitude` = -6.4167,  `longitude` = 20.8000  WHERE `nom` = 'Tshikapa';
UPDATE `villes` SET `latitude` = 1.5667,   `longitude` = 30.2500  WHERE `nom` = 'Bunia';
UPDATE `villes` SET `latitude` = 2.7833,   `longitude` = 24.7333  WHERE `nom` = 'Buta';
UPDATE `villes` SET `latitude` = 2.7733,   `longitude` = 27.6167  WHERE `nom` = 'Isiro';
UPDATE `villes` SET `latitude` = -5.1333,  `longitude` = 24.3500  WHERE `nom` = 'Kabinda';
UPDATE `villes` SET `latitude` = -5.9500,  `longitude` = 29.1833  WHERE `nom` = 'Kalemie';
UPDATE `villes` SET `latitude` = -8.7333,  `longitude` = 24.9833  WHERE `nom` = 'Kamina';
UPDATE `villes` SET `latitude` = -5.7833,  `longitude` = 13.6500  WHERE `nom` = 'Kenge';
UPDATE `villes` SET `latitude` = -5.0333,  `longitude` = 18.7833  WHERE `nom` = 'Kikwit';
UPDATE `villes` SET `latitude` = -2.9500,  `longitude` = 25.9500  WHERE `nom` = 'Kindu';
UPDATE `villes` SET `latitude` = -10.7167, `longitude` = 25.4667  WHERE `nom` = 'Kolwezi';
UPDATE `villes` SET `latitude` = -10.9833, `longitude` = 26.7333  WHERE `nom` = 'Likasi';
UPDATE `villes` SET `latitude` = 2.1500,   `longitude` = 21.5167  WHERE `nom` = 'Lisala';
UPDATE `villes` SET `latitude` = -5.8167,  `longitude` = 13.4500  WHERE `nom` = 'Matadi';
UPDATE `villes` SET `latitude` = 0.0500,   `longitude` = 18.2667  WHERE `nom` = 'Mbandaka';
UPDATE `villes` SET `latitude` = -3.3167,  `longitude` = 17.3667  WHERE `nom` = 'Bandundu';
UPDATE `villes` SET `latitude` = -0.2167,  `longitude` = 20.8500  WHERE `nom` = 'Boende';
UPDATE `villes` SET `latitude` = -5.8500,  `longitude` = 13.0500  WHERE `nom` = 'Boma';
UPDATE `villes` SET `latitude` = 3.2500,   `longitude` = 19.7667  WHERE `nom` = 'Gemena';
UPDATE `villes` SET `latitude` = 4.2833,   `longitude` = 20.7167  WHERE `nom` = 'Gbadolite';
UPDATE `villes` SET `latitude` = -0.8333,  `longitude` = 18.2833  WHERE `nom` = 'Inongo';
UPDATE `villes` SET `latitude` = -4.4783,  `longitude` = 15.1333  WHERE `nom` = 'Kasangulu';
UPDATE `villes` SET `latitude` = -4.9500,  `longitude` = 20.8500  WHERE `nom` = 'Lusambo';
UPDATE `villes` SET `latitude` = -1.6167,  `longitude` = 29.3300  WHERE `nom` = 'Sake';
UPDATE `villes` SET `latitude` = -3.3733,  `longitude` = 29.1400  WHERE `nom` = 'Uvira';
UPDATE `villes` SET `latitude` = 2.2500,   `longitude` = 22.4667  WHERE `nom` = 'Bumba';

-- 3) Coordonnees des communes (Kinshasa + Lubumbashi)
UPDATE `communes` SET `latitude` = -4.3250, `longitude` = 15.2980 WHERE `nom` = 'Gombe';
UPDATE `communes` SET `latitude` = -4.3180, `longitude` = 15.3050 WHERE `nom` = 'Lingwala';
UPDATE `communes` SET `latitude` = -4.3150, `longitude` = 15.2850 WHERE `nom` = 'Kinshasa';
UPDATE `communes` SET `latitude` = -4.3350, `longitude` = 15.3150 WHERE `nom` = 'Barumbu';
UPDATE `communes` SET `latitude` = -4.3400, `longitude` = 15.3050 WHERE `nom` = 'Kasa-Vubu';
UPDATE `communes` SET `latitude` = -4.3450, `longitude` = 15.2900 WHERE `nom` = 'Kalamu';
UPDATE `communes` SET `latitude` = -4.3500, `longitude` = 15.2850 WHERE `nom` = 'Ngiri-Ngiri';
UPDATE `communes` SET `latitude` = -4.3550, `longitude` = 15.2750 WHERE `nom` = 'Bandalungwa';
UPDATE `communes` SET `latitude` = -4.3650, `longitude` = 15.2500 WHERE `nom` = 'Kintambo';
UPDATE `communes` SET `latitude` = -4.3750, `longitude` = 15.2350 WHERE `nom` = 'Ngaliema';
UPDATE `communes` SET `latitude` = -4.4100, `longitude` = 15.2250 WHERE `nom` = 'Selembao';
UPDATE `communes` SET `latitude` = -4.3950, `longitude` = 15.2550 WHERE `nom` = 'Bumbu';
UPDATE `communes` SET `latitude` = -4.3800, `longitude` = 15.3000 WHERE `nom` = 'Makala';
UPDATE `communes` SET `latitude` = -4.4700, `longitude` = 15.2500 WHERE `nom` = 'Mont-Ngafula';
UPDATE `communes` SET `latitude` = -4.4400, `longitude` = 15.4000 WHERE `nom` = 'Kimbanseke';
UPDATE `communes` SET `latitude` = -4.3800, `longitude` = 15.3900 WHERE `nom` = 'Masina';
UPDATE `communes` SET `latitude` = -4.4200, `longitude` = 15.3700 WHERE `nom` = 'Ndjili';
UPDATE `communes` SET `latitude` = -4.3900, `longitude` = 15.3400 WHERE `nom` = 'Lemba';
UPDATE `communes` SET `latitude` = -4.4000, `longitude` = 15.3300 WHERE `nom` = 'Ngaba';
UPDATE `communes` SET `latitude` = -4.4200, `longitude` = 15.3200 WHERE `nom` = 'Kisenso';
UPDATE `communes` SET `latitude` = -4.3600, `longitude` = 15.3500 WHERE `nom` = 'Limete';
UPDATE `communes` SET `latitude` = -4.3700, `longitude` = 15.3500 WHERE `nom` = 'Matete';
UPDATE `communes` SET `latitude` = -4.5500, `longitude` = 15.4500 WHERE `nom` = 'N''Sele';
UPDATE `communes` SET `latitude` = -4.4000, `longitude` = 15.6000 WHERE `nom` = 'Maluku';
UPDATE `communes` SET `latitude` = -11.6700, `longitude` = 27.4700 WHERE `nom` = 'Lubumbashi';
UPDATE `communes` SET `latitude` = -11.6550, `longitude` = 27.4950 WHERE `nom` = 'Kamalondo';

SELECT COUNT(*) AS villes_geo FROM `villes` WHERE `latitude` IS NOT NULL;
SELECT COUNT(*) AS communes_geo FROM `communes` WHERE `latitude` IS NOT NULL;
