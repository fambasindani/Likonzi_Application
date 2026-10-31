-- MySQL dump 10.13  Distrib 8.0.34, for Win64 (x86_64)
--
-- Host: localhost    Database: securite_sociale
-- ------------------------------------------------------
-- Server version	8.0.11

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `demandes`
--

DROP TABLE IF EXISTS `demandes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `demandes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `recev_id` int(11) NOT NULL,
  `envoi_id` int(11) NOT NULL,
  `datedemande` datetime NOT NULL,
  `confirmation` tinyint(1) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=363 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `demandes`
--

LOCK TABLES `demandes` WRITE;
/*!40000 ALTER TABLE `demandes` DISABLE KEYS */;
INSERT INTO `demandes` VALUES (348,27,1,'2024-11-14 13:18:05',1),(350,27,29,'2024-11-15 13:58:45',0),(354,1,29,'2024-11-15 13:58:45',1),(355,5,29,'2024-11-15 16:42:01',0),(356,1,28,'2024-11-16 17:04:26',1),(357,27,28,'2024-11-16 17:04:42',0),(358,28,29,'2024-11-16 17:05:47',1),(359,28,30,'2024-11-16 17:18:37',1),(360,9,27,'2024-11-22 17:49:33',0),(362,57,27,'2024-12-13 12:18:10',1);
/*!40000 ALTER TABLE `demandes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `imgs`
--

DROP TABLE IF EXISTS `imgs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `imgs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `image` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=35 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `imgs`
--

LOCK TABLES `imgs` WRITE;
/*!40000 ALTER TABLE `imgs` DISABLE KEYS */;
INSERT INTO `imgs` VALUES (13,'e71668c4-22b1-4dd8-bbfa-507da9a764cf.jpeg'),(14,'ed34308d-3fad-432d-8f41-1ec8c41e1a70.jpeg'),(15,'ed34308d-3fad-432d-8f41-1ec8c41e1a70.jpeg'),(16,'ed34308d-3fad-432d-8f41-1ec8c41e1a70.jpeg'),(17,'ed34308d-3fad-432d-8f41-1ec8c41e1a70.jpeg'),(18,'ed34308d-3fad-432d-8f41-1ec8c41e1a70.jpeg'),(19,'ed34308d-3fad-432d-8f41-1ec8c41e1a70.jpeg'),(20,'ed34308d-3fad-432d-8f41-1ec8c41e1a70.jpeg'),(21,'ed34308d-3fad-432d-8f41-1ec8c41e1a70.jpeg'),(22,'5c516333-07f6-4c2c-b8e2-8701b32e1212.jpeg'),(23,'5c516333-07f6-4c2c-b8e2-8701b32e1212.jpeg'),(24,'ed34308d-3fad-432d-8f41-1ec8c41e1a70.jpeg'),(25,'ff8fd44e-e458-4a0d-a7cd-b16c2a8d7aa3.jpeg'),(26,'ed34308d-3fad-432d-8f41-1ec8c41e1a70.jpeg'),(27,'ed34308d-3fad-432d-8f41-1ec8c41e1a70.jpeg'),(28,'8e9679c7-166d-4328-8bbf-239816fd58c4.jpeg'),(29,'c8409695-7c7f-4468-95b8-e60f31b42306.jpeg'),(30,'47a134dd-5150-4540-9667-515cc21d54f7.jpeg'),(31,'7b864c9f-285a-4ccd-8598-90557b5ba081.jpeg'),(32,'user.png'),(33,'téléchargement.png'),(34,'1f0e6eb2-2815-4d2b-85d0-097205bafecd.png');
/*!40000 ALTER TABLE `imgs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Temporary view structure for view `listeami`
--

DROP TABLE IF EXISTS `listeami`;
/*!50001 DROP VIEW IF EXISTS `listeami`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `listeami` AS SELECT 
 1 AS `iduser`,
 1 AS `nom`,
 1 AS `postnom`,
 1 AS `prenom`,
 1 AS `email`,
 1 AS `avatar`,
 1 AS `telephone`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `listeamis`
--

DROP TABLE IF EXISTS `listeamis`;
/*!50001 DROP VIEW IF EXISTS `listeamis`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `listeamis` AS SELECT 
 1 AS `id`,
 1 AS `nom`,
 1 AS `postnom`,
 1 AS `prenom`,
 1 AS `password`,
 1 AS `email`,
 1 AS `avatar`,
 1 AS `telephone`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `listeavatars`
--

DROP TABLE IF EXISTS `listeavatars`;
/*!50001 DROP VIEW IF EXISTS `listeavatars`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `listeavatars` AS SELECT 
 1 AS `id`,
 1 AS `id_type`,
 1 AS `iduser`,
 1 AS `marque`,
 1 AS `model`,
 1 AS `numero_chassis`,
 1 AS `immatriculation`,
 1 AS `description`,
 1 AS `avatar`,
 1 AS `telephone`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `listedemandeacceptes`
--

DROP TABLE IF EXISTS `listedemandeacceptes`;
/*!50001 DROP VIEW IF EXISTS `listedemandeacceptes`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `listedemandeacceptes` AS SELECT 
 1 AS `idc`,
 1 AS `id`,
 1 AS `nom`,
 1 AS `postnom`,
 1 AS `prenom`,
 1 AS `email`,
 1 AS `password`,
 1 AS `avatar`,
 1 AS `telephone`,
 1 AS `recev_id`,
 1 AS `datedemande`,
 1 AS `envoi_id`,
 1 AS `confirmation`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `listedemandes`
--

DROP TABLE IF EXISTS `listedemandes`;
/*!50001 DROP VIEW IF EXISTS `listedemandes`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `listedemandes` AS SELECT 
 1 AS `idc`,
 1 AS `id`,
 1 AS `nom`,
 1 AS `postnom`,
 1 AS `prenom`,
 1 AS `email`,
 1 AS `password`,
 1 AS `avatar`,
 1 AS `telephone`,
 1 AS `recev_id`,
 1 AS `datedemande`,
 1 AS `envoi_id`,
 1 AS `confirmation`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `listelocalisations`
--

DROP TABLE IF EXISTS `listelocalisations`;
/*!50001 DROP VIEW IF EXISTS `listelocalisations`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `listelocalisations` AS SELECT 
 1 AS `id`,
 1 AS `iduser`,
 1 AS `email`,
 1 AS `longitude`,
 1 AS `latitude`,
 1 AS `longitudeDelta`,
 1 AS `latitudeDelta`,
 1 AS `datelocalisation`,
 1 AS `nom`,
 1 AS `prenom`,
 1 AS `postnom`,
 1 AS `telephone`,
 1 AS `avatar`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `listenotificationobjets`
--

DROP TABLE IF EXISTS `listenotificationobjets`;
/*!50001 DROP VIEW IF EXISTS `listenotificationobjets`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `listenotificationobjets` AS SELECT 
 1 AS `id`,
 1 AS `nom`,
 1 AS `postnom`,
 1 AS `prenom`,
 1 AS `email`,
 1 AS `avatar`,
 1 AS `telephone`,
 1 AS `recev_id`,
 1 AS `envoi_id`,
 1 AS `contenu`,
 1 AS `id_objet`,
 1 AS `datenotification`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `listenotifications`
--

DROP TABLE IF EXISTS `listenotifications`;
/*!50001 DROP VIEW IF EXISTS `listenotifications`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `listenotifications` AS SELECT 
 1 AS `id`,
 1 AS `nom`,
 1 AS `postnom`,
 1 AS `prenom`,
 1 AS `email`,
 1 AS `avatar`,
 1 AS `telephone`,
 1 AS `recev_id`,
 1 AS `envoi_id`,
 1 AS `contenu`,
 1 AS `datenotification`*/;
SET character_set_client = @saved_cs_client;

--
-- Temporary view structure for view `listeobjets`
--

DROP TABLE IF EXISTS `listeobjets`;
/*!50001 DROP VIEW IF EXISTS `listeobjets`*/;
SET @saved_cs_client     = @@character_set_client;
/*!50503 SET character_set_client = utf8mb4 */;
/*!50001 CREATE VIEW `listeobjets` AS SELECT 
 1 AS `id`,
 1 AS `id_type`,
 1 AS `iduser`,
 1 AS `marque`,
 1 AS `model`,
 1 AS `numero_chassis`,
 1 AS `immatriculation`,
 1 AS `description`*/;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `localisations`
--

DROP TABLE IF EXISTS `localisations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `localisations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `iduser` int(11) NOT NULL,
  `longitude` float NOT NULL,
  `latitude` float NOT NULL,
  `datelocalisation` datetime NOT NULL,
  `longitudeDelta` float DEFAULT NULL,
  `latitudeDelta` float DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `localisations`
--

LOCK TABLES `localisations` WRITE;
/*!40000 ALTER TABLE `localisations` DISABLE KEYS */;
INSERT INTO `localisations` VALUES (1,1,15.3121,-4.2984,'2025-02-18 19:27:32',0.0900845,0.0898311),(2,25,15.2102,-4.35333,'2024-11-08 13:15:12',0.0421,0.0922),(3,27,15.3121,-4.2984,'2025-02-18 19:19:06',0.0900845,0.0898311),(4,28,15.2098,-4.35302,'2024-11-22 23:41:10',0.090091,0.0898311),(5,29,15.3121,-4.29841,'2024-11-22 17:54:48',0.0900845,0.0898311),(6,30,15.3121,-4.29841,'2024-11-22 18:55:03',0.0900845,0.0898311),(10,33,15.312,-4.29842,'2024-11-19 14:01:50',0.0900845,0.0898311),(11,54,15.3121,-4.29841,'2024-11-22 18:00:34',0.0900845,0.0898311),(14,56,15.2105,-4.35364,'2024-11-22 23:52:02',0.0900911,0.0898311),(15,57,15.312,-4.29838,'2024-12-13 15:49:08',0.0900845,0.0898311);
/*!40000 ALTER TABLE `localisations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `mesnotification`
--

DROP TABLE IF EXISTS `mesnotification`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `mesnotification` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_rec` int(11) NOT NULL,
  `id_sender` int(11) NOT NULL,
  `messages` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `mesnotification`
--

LOCK TABLES `mesnotification` WRITE;
/*!40000 ALTER TABLE `mesnotification` DISABLE KEYS */;
/*!40000 ALTER TABLE `mesnotification` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notes`
--

DROP TABLE IF EXISTS `notes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_rec` int(11) NOT NULL,
  `messages` varchar(400) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `id_sender` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notes`
--

LOCK TABLES `notes` WRITE;
/*!40000 ALTER TABLE `notes` DISABLE KEYS */;
INSERT INTO `notes` VALUES (2,1,'blabla',16);
/*!40000 ALTER TABLE `notes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notification_objets`
--

DROP TABLE IF EXISTS `notification_objets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notification_objets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `recev_id` int(11) DEFAULT NULL,
  `envoi_id` int(11) DEFAULT NULL,
  `id_objet` int(11) DEFAULT NULL,
  `contenu` varchar(345) DEFAULT NULL,
  `datenotification` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notification_objets`
--

LOCK TABLES `notification_objets` WRITE;
/*!40000 ALTER TABLE `notification_objets` DISABLE KEYS */;
INSERT INTO `notification_objets` VALUES (6,27,1,11,'ordinateur volée','2024-12-13 13:29:55'),(7,27,57,11,'ordinateur volée','2024-12-13 13:29:55'),(8,27,1,15,'Voiture volé(e)','2024-12-13 13:43:17'),(9,27,57,15,'Voiture volé(e)','2024-12-13 13:43:17'),(10,57,27,11,'Voiture volé(e)','2024-12-13 14:49:11');
/*!40000 ALTER TABLE `notification_objets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `recev_id` int(11) NOT NULL,
  `envoi_id` int(11) NOT NULL,
  `contenu` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `datenotification` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=500 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
INSERT INTO `notifications` VALUES (427,1,29,'Kuluna m\'a attaqué','2024-11-15 16:30:21'),(428,27,1,'Kuluna m\'a attaqué','2024-11-16 17:00:35'),(429,1,27,'Je suis en danger','2024-11-16 17:06:46'),(430,1,29,'Je suis en danger','2024-11-16 17:06:46'),(431,1,28,'Je suis en danger','2024-11-16 17:06:46'),(432,1,27,'Kuluna m\'a attaqué','2024-11-16 17:08:17'),(433,1,29,'Kuluna m\'a attaqué','2024-11-16 17:08:17'),(434,1,28,'Kuluna m\'a attaqué','2024-11-16 17:08:17'),(435,1,27,'Je suis en classe','2024-11-16 17:10:19'),(436,1,29,'Je suis en classe','2024-11-16 17:10:19'),(437,1,28,'Je suis en classe','2024-11-16 17:10:19'),(438,1,27,'Kuluna m\'a attaqué','2024-11-16 17:12:06'),(439,1,29,'Kuluna m\'a attaqué','2024-11-16 17:12:06'),(440,1,28,'Kuluna m\'a attaqué','2024-11-16 17:12:06'),(441,28,1,'Je suis en danger','2024-11-16 17:12:23'),(442,30,28,'Kuluna m\'a attaqué','2024-11-16 17:19:47'),(443,28,1,'Je suis en danger','2024-11-16 17:20:32'),(444,28,29,'Je suis en danger','2024-11-16 17:20:32'),(445,28,30,'Je suis en danger','2024-11-16 17:20:32'),(446,30,28,'Kuluna m\'a attaqué','2024-11-16 17:22:03'),(447,30,28,'Je suis en classe','2024-11-16 17:22:39'),(448,28,1,'Kuluna m\'a attaqué','2024-11-16 17:23:09'),(449,28,29,'Kuluna m\'a attaqué','2024-11-16 17:23:09'),(450,28,30,'Kuluna m\'a attaqué','2024-11-16 17:23:09'),(451,30,28,'je suis hospitalisé','2024-11-16 17:25:17'),(452,30,28,'Je suis en classe','2024-11-16 17:25:37'),(453,1,27,'Kuluna m\'a attaqué','2024-11-17 07:56:08'),(454,1,29,'Kuluna m\'a attaqué','2024-11-17 07:56:08'),(455,1,28,'Kuluna m\'a attaqué','2024-11-17 07:56:08'),(456,1,27,'Kuluna m\'a attaqué','2024-11-17 07:57:02'),(457,1,29,'Kuluna m\'a attaqué','2024-11-17 07:57:02'),(458,1,28,'Kuluna m\'a attaqué','2024-11-17 07:57:02'),(459,1,27,'Kuluna m\'a attaqué','2024-11-17 07:58:03'),(460,1,29,'Kuluna m\'a attaqué','2024-11-17 07:58:03'),(461,1,28,'Kuluna m\'a attaqué','2024-11-17 07:58:03'),(462,1,27,'Je suis en classe','2024-11-17 07:58:44'),(463,1,29,'Je suis en classe','2024-11-17 07:58:44'),(464,1,28,'Je suis en classe','2024-11-17 07:58:44'),(465,1,27,'Je suis en classe','2024-11-17 07:59:07'),(466,1,29,'Je suis en classe','2024-11-17 07:59:07'),(467,1,28,'Je suis en classe','2024-11-17 07:59:07'),(468,1,27,'Je suis en classe','2024-11-17 07:59:29'),(469,1,29,'Je suis en classe','2024-11-17 07:59:29'),(470,1,28,'Je suis en classe','2024-11-17 07:59:29'),(471,27,1,'Je suis en classe','2024-11-17 08:00:17'),(472,27,1,'je suis hospitalisé','2024-11-17 08:01:13'),(473,27,1,'Je suis en danger','2024-11-17 08:01:50'),(474,27,1,'Kuluna m\'a attaqué','2024-11-17 08:02:33'),(475,27,1,'Kuluna m\'a attaqué','2024-11-17 08:05:53'),(476,27,1,'Je suis en classe','2024-11-17 08:06:20'),(477,27,1,'Kuluna m\'a attaqué','2024-11-17 08:11:21'),(478,27,1,'Je suis en classe','2024-11-17 08:11:49'),(479,29,1,'Kuluna m\'a attaqué','2024-11-17 08:13:00'),(480,29,28,'Kuluna m\'a attaqué','2024-11-17 08:13:00'),(481,29,1,'je suis hospitalisé','2024-11-17 08:15:05'),(482,29,28,'je suis hospitalisé','2024-11-17 08:15:05'),(483,1,27,'Je suis en classe','2024-11-17 08:15:51'),(484,1,29,'Je suis en classe','2024-11-17 08:15:51'),(485,1,28,'Je suis en classe','2024-11-17 08:15:51'),(486,1,27,'Je suis en classe','2024-11-17 08:17:08'),(487,1,29,'Je suis en classe','2024-11-17 08:17:08'),(488,1,28,'Je suis en classe','2024-11-17 08:17:08'),(489,28,1,'je suis hospitalisé','2024-11-17 16:36:57'),(490,28,29,'je suis hospitalisé','2024-11-17 16:36:57'),(491,28,30,'je suis hospitalisé','2024-11-17 16:36:57'),(492,30,28,'Kuluna m\'a attaqué','2024-11-17 16:37:54'),(493,27,1,'Je suis attaqué par de kuluna , je suis en danger','2024-11-22 17:49:57'),(494,54,27,'Kuluna m\'a attaqué','2024-11-22 18:00:05'),(495,1,27,'mon contenu','2024-11-24 10:57:45'),(496,1,29,'mon contenu','2024-11-24 10:57:45'),(497,1,28,'mon contenu','2024-11-24 10:57:45'),(498,27,1,'mon contenu','2024-11-24 11:46:46'),(499,27,1,'Je suis en classe','2024-12-13 12:11:48');
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `objet_avatars`
--

DROP TABLE IF EXISTS `objet_avatars`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `objet_avatars` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_objet` int(11) DEFAULT NULL,
  `avatar` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=73 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `objet_avatars`
--

LOCK TABLES `objet_avatars` WRITE;
/*!40000 ALTER TABLE `objet_avatars` DISABLE KEYS */;
INSERT INTO `objet_avatars` VALUES (47,11,'1000128206.jpg'),(48,11,'1000128128.jpg'),(49,11,'1000128114.jpg'),(62,15,'1000129501.jpg'),(63,15,'1000129500.jpg'),(64,15,'1000129499.jpg'),(65,15,'1000129497.jpg'),(66,15,'1000129498.jpg'),(67,16,'1000129499.jpg'),(68,16,'1000129501.jpg'),(69,16,'1000129498.jpg'),(70,16,'1000129497.jpg'),(71,16,'1000129500.jpg');
/*!40000 ALTER TABLE `objet_avatars` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `objet_notifications`
--

DROP TABLE IF EXISTS `objet_notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `objet_notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `recev_id` int(11) DEFAULT NULL,
  `envoi_id` int(11) DEFAULT NULL,
  `contenu` varchar(245) DEFAULT NULL,
  `datenotification` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `objet_notifications`
--

LOCK TABLES `objet_notifications` WRITE;
/*!40000 ALTER TABLE `objet_notifications` DISABLE KEYS */;
/*!40000 ALTER TABLE `objet_notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `objets`
--

DROP TABLE IF EXISTS `objets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `objets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `id_type` int(11) DEFAULT NULL,
  `iduser` int(11) DEFAULT NULL,
  `marque` varchar(145) DEFAULT NULL,
  `model` varchar(145) DEFAULT NULL,
  `numero_chassis` varchar(145) DEFAULT NULL,
  `immatriculation` varchar(145) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `objets`
--

LOCK TABLES `objets` WRITE;
/*!40000 ALTER TABLE `objets` DISABLE KEYS */;
INSERT INTO `objets` VALUES (11,2,57,'Toyota ','Marc x','',''),(15,2,27,'Nissan','Jaguar ','156788','45677'),(16,4,27,'Kinga','Kinga','','');
/*!40000 ALTER TABLE `objets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `type_objets`
--

DROP TABLE IF EXISTS `type_objets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `type_objets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `description` varchar(145) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `type_objets`
--

LOCK TABLES `type_objets` WRITE;
/*!40000 ALTER TABLE `type_objets` DISABLE KEYS */;
INSERT INTO `type_objets` VALUES (1,'Moto'),(2,'Voiture'),(3,'Ordinateur'),(4,'Vélo ');
/*!40000 ALTER TABLE `type_objets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `typealertes`
--

DROP TABLE IF EXISTS `typealertes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `typealertes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `contenu` varchar(60) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `typealertes`
--

LOCK TABLES `typealertes` WRITE;
/*!40000 ALTER TABLE `typealertes` DISABLE KEYS */;
INSERT INTO `typealertes` VALUES (1,'Je suis en danger '),(2,'je suis hospitalisé'),(3,'Je suis en classe'),(4,'Kuluna m\'a attaqué'),(6,'Je suis attaqué par de kuluna , je suis en danger');
/*!40000 ALTER TABLE `typealertes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nom` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `postnom` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `prenom` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `email` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `password` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `avatar` text CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `telephone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL,
  `role` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT NULL,
  `adresse` varchar(245) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `datenaissance` date DEFAULT NULL,
  `gerne` varchar(45) COLLATE utf8mb4_general_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=63 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'Famba','Ngoy','Pierre','pierrpapy@gmail.com','$2b$12$ciT028jswv7Ek6j6KPet5uJMvlSTaM905gocGvigK0CJ6xjTiT1Ty','k.jpg','0898596591','1','KINGU 12','2005-02-15','Masculin'),(5,'Kilangalanga','Ngayenge','Jean-Pierre','pierrepapy@gmail.com','$2b$12$trZeVx4CNHtp8EgblRgYGOdtrEQnRxBRggwufPHfo/2EdiDhdNxVG','user.png','0898560566788','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(6,'Ngoma','Kwesabio ','Moïse ','pierrepapys@gmail.com','$2b$12$uQqwJDReE1HN75avyzy8te4S9nRKNlRst8/vC76XsWpwKbvPCuDly','user.png','0898596501','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(7,'Bola','Lobota','Patrick ','bola@gmail.com','$2b$12$QTYcgE/HpXW5spEJISHeCuXH/A2CaYexKHniGgo6Ycu.cNBO9BV/6','3a21f4cb-271f-4863-b9de-42a950aaacf6.jpeg','0818596501','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(9,'Sindani','Sindani','Josiane','epiphani@gmail.com','$2b$12$RXPw4f1uiCsBT9n3XBfI5uH1mVLxEupOehybWEvin3VidTkPb2aae','29ca863a-bf2b-4ca8-8b00-b3e8e17eeb79.jpeg','0812345687','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(10,'Kasereka ','Kalimumbalo','Eric','kalimumbalo@gmail.com','$2b$12$2v34eBm.pXW8zO66EE4CV.A.beD6Xj3aYgyg179DLciSAU/R1X2Ki','user.png','00034','2','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','F'),(11,'Mitongo','Kabeya','Renedis','mito@gmail.com','$2b$12$47TQJvoIoyb4ZY1Tu2R/0.rzuHSC0jDDsXcZX1GJndApDlGfLFWyO','user.png','057777','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(12,'Kibeti','Sulu','Dan','kibeti@gmail.com','$2b$12$ne9Z2ZxsZqu89J25UAQg9eZWroLvOeY7RixzjAJEeanBTJ//n8QVy','user.png','087654','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(13,'Ilongo','Tokombe','Jean','tokombe@gmail.com','$2b$12$ItNFVe9Bg7cH0RbXc6BkIeKRtbXK0mVOQMzmCxVIb7D3.YGc0n/TO','user.png','87655','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','F'),(14,'Jiji','Balue','Patrick ','jiji@gmail.com','$2b$12$Mc0AhPfE5woy74sShjuE4OaCuiR0cOVOzJ0IVL86d/vWo4BmmK582','user.png','8765555','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(15,'Kalume','Kamango','Papy','kamango@gmail.com','$2b$12$JJGH/Px2W9m3bYvvlw1RSeyD2rmqfcaR1/mjdt71W2X4usjswwCCe','user.png','677888','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(16,'Ngoy','Yambayamba','Papy','ngoy@gmail.com','$2b$12$qw/MuotyTnsdQ7zW1vs1i.OGYjwebmvOTXEnbCkaOIYtNDcue/FDe','user.png','786544','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(17,'Kambale','Kahongwa','Serge','kahingwa@gmail.com','$2b$12$sd7FINRFY090qMwsRHXjVOo7QdhcR0Kf6G9qr.L/PREIIhxHU2MZe','a1d6ad7e-646c-4d9b-a812-deaeea91e77b.jpeg','865438677','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(18,'Mulamba','Kibonge','Gédéon ','mulamba@gmail.com','$2b$12$hehFX9FNyqUOGvl7cggilOCDVS8DL6sZbDV2awa037FwRyh7eE4VC','dbfc1084-d019-4bc7-85e9-1bdc5b23087c.jpeg','876555556','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(19,'Nsevani','Kitonge','Manassé ','nsevani@gmail.com','$2b$12$G2peGs5XuZwfFuTn.M0Hce6dk2nmDp.tJuvGcmpJEKHnDgGXbEaey','user.png','567778','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(27,'Nguizani','Taty','Taty','nguizani@gmail.com','$2b$12$YGOJkARTIm0J.YN0Sb0k3eUNWYaAPWQlcs4xLQEiqDPqtkus2uqM6','5564b6e3-30a5-494e-9da1-0be61bae09ee.jpeg','123457886','0','C/KALAMU, Q/CPA-MUSI, AV/MENGI 14','1998-02-13','Masculin'),(28,'Strong',NULL,NULL,'guyngoy99@gmail.com','$2b$12$4Vk74SiCMBz7tHiR8MPqE.n01tNhoC5NPzwgv2cFrNnSYW4pAmkIu','3118bf24-e035-4e4c-8c6e-66c9467e5add.jpeg','0987337388','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(29,'Buediena','Kabu','Berthier ','buediena@gmail.com','$2b$12$3GAk2b8HBsdR4uPEPvbQBO9kPVS8T.uJdGWGLVm1DryAKqc0HpiaC','54f69577-8fb6-4f1e-8d90-130577db6011.jpeg','08567754357','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(30,'Sindani',NULL,'Josiane','sindani@gmail.com','$2b$12$iXB49q8dwqhTh0DVMUI8lO432I8J1AyY4uWEg5Gpylm9GPy1hu94q','c6d1efff-8226-4638-a843-5eb16aeadbab.jpeg','12345688','1','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(52,'Kilandamoko',NULL,'Chirac','kilanda@gmail.com','$2b$12$rVITxCL3J.oawdVvDO1jROwniI6MvI.eD.Ewu0.iLBQn0HTpWDjp6','user.png','2341777','1','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(53,'Kasongo',NULL,'Marie','kas@gmail.com','$2b$12$0wxeA2qMQPMuJUvNn7.3y.mDMKN6EoXO0GVadKDBzh2USLDyJM/1i','user.png','1234667','1','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(56,'Mika',NULL,NULL,'mika@gmail.com','$2b$12$Xcm/GuaNYrP5A0rcSfhrQe6l3DR2/sYtz3.5iD/hdtPNmyRwO5KcC','user.png','33452245','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(57,'h',NULL,NULL,'h@gmail.com','$2b$12$UBaM1BkkVMvo5fZNQwVkeuNFumBJm74STtHqVsT5oDS6Mha0cRj/m','user.png','0818596501','0','C/KALAMU, Q/CPA-MUSI, AV/MEGI 5','2008-02-02','M'),(58,'FA',NULL,'MM','a@kkkkj','$2b$12$LNlUB6ZNDckGZF9cQy43bOizLAkXVeRpC2u.tNoh9M6JBbSbQEuQu','user.png','23665424',NULL,NULL,'2025-02-02','M'),(60,'Malula',NULL,NULL,'malula@gmail.com','$2b$12$n2coXbkrciQMYy1XAkHeS.Ol7CystVl8Zaap8yA5/1j9iS1JdXGga','user.png','09865544445','0','C/Mont Ngafula, Q/Herady , Av/Mbujimayi 23','1985-09-09','Masculin');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `validations`
--

DROP TABLE IF EXISTS `validations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `validations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `iduser` int(11) NOT NULL,
  `datevalidation` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `validations`
--

LOCK TABLES `validations` WRITE;
/*!40000 ALTER TABLE `validations` DISABLE KEYS */;
/*!40000 ALTER TABLE `validations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Final view structure for view `listeami`
--

/*!50001 DROP VIEW IF EXISTS `listeami`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `listeami` AS select `users`.`id` AS `iduser`,`users`.`nom` AS `nom`,`users`.`postnom` AS `postnom`,`users`.`prenom` AS `prenom`,`users`.`email` AS `email`,`users`.`avatar` AS `avatar`,`users`.`telephone` AS `telephone` from (`users` left join `demandes` on((`users`.`id` = `demandes`.`envoi_id`))) where isnull(`demandes`.`envoi_id`) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `listeamis`
--

/*!50001 DROP VIEW IF EXISTS `listeamis`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `listeamis` AS select `users`.`id` AS `id`,`users`.`nom` AS `nom`,`users`.`postnom` AS `postnom`,`users`.`prenom` AS `prenom`,`users`.`password` AS `password`,`users`.`email` AS `email`,`users`.`avatar` AS `avatar`,`users`.`telephone` AS `telephone` from `users` where (not(`users`.`id` in (select `demandes`.`recev_id` from `demandes` where (`demandes`.`envoi_id` = '1')))) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `listeavatars`
--

/*!50001 DROP VIEW IF EXISTS `listeavatars`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `listeavatars` AS select `objets`.`id` AS `id`,`objets`.`id_type` AS `id_type`,`objets`.`iduser` AS `iduser`,`objets`.`marque` AS `marque`,`objets`.`model` AS `model`,`objets`.`numero_chassis` AS `numero_chassis`,`objets`.`immatriculation` AS `immatriculation`,`type_objets`.`description` AS `description`,`objet_avatars`.`avatar` AS `avatar`,`users`.`telephone` AS `telephone` from (((`objets` join `type_objets`) join `objet_avatars`) join `users`) where ((`type_objets`.`id` = `objets`.`id_type`) and (`objet_avatars`.`id_objet` = `objets`.`id`) and (`users`.`id` = `objets`.`iduser`)) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `listedemandeacceptes`
--

/*!50001 DROP VIEW IF EXISTS `listedemandeacceptes`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `listedemandeacceptes` AS select `demandes`.`id` AS `idc`,`users`.`id` AS `id`,`users`.`nom` AS `nom`,`users`.`postnom` AS `postnom`,`users`.`prenom` AS `prenom`,`users`.`email` AS `email`,`users`.`password` AS `password`,`users`.`avatar` AS `avatar`,`users`.`telephone` AS `telephone`,`demandes`.`recev_id` AS `recev_id`,`demandes`.`datedemande` AS `datedemande`,`demandes`.`envoi_id` AS `envoi_id`,`demandes`.`confirmation` AS `confirmation` from (`demandes` join `users`) where ((`users`.`id` = `demandes`.`envoi_id`) and (`demandes`.`confirmation` = '1')) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `listedemandes`
--

/*!50001 DROP VIEW IF EXISTS `listedemandes`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `listedemandes` AS select `demandes`.`id` AS `idc`,`users`.`id` AS `id`,`users`.`nom` AS `nom`,`users`.`postnom` AS `postnom`,`users`.`prenom` AS `prenom`,`users`.`email` AS `email`,`users`.`password` AS `password`,`users`.`avatar` AS `avatar`,`users`.`telephone` AS `telephone`,`demandes`.`recev_id` AS `recev_id`,`demandes`.`datedemande` AS `datedemande`,`demandes`.`envoi_id` AS `envoi_id`,`demandes`.`confirmation` AS `confirmation` from (`demandes` join `users`) where ((`users`.`id` = `demandes`.`envoi_id`) and (`demandes`.`confirmation` = '0')) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `listelocalisations`
--

/*!50001 DROP VIEW IF EXISTS `listelocalisations`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `listelocalisations` AS select `localisations`.`id` AS `id`,`localisations`.`iduser` AS `iduser`,`users`.`email` AS `email`,`localisations`.`longitude` AS `longitude`,`localisations`.`latitude` AS `latitude`,`localisations`.`longitudeDelta` AS `longitudeDelta`,`localisations`.`latitudeDelta` AS `latitudeDelta`,`localisations`.`datelocalisation` AS `datelocalisation`,`users`.`nom` AS `nom`,`users`.`prenom` AS `prenom`,`users`.`postnom` AS `postnom`,`users`.`telephone` AS `telephone`,`users`.`avatar` AS `avatar` from (`users` join `localisations`) where (`users`.`id` = `localisations`.`iduser`) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `listenotificationobjets`
--

/*!50001 DROP VIEW IF EXISTS `listenotificationobjets`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `listenotificationobjets` AS select `notification_objets`.`id` AS `id`,`users`.`nom` AS `nom`,`users`.`postnom` AS `postnom`,`users`.`prenom` AS `prenom`,`users`.`email` AS `email`,`users`.`avatar` AS `avatar`,`users`.`telephone` AS `telephone`,`notification_objets`.`recev_id` AS `recev_id`,`notification_objets`.`envoi_id` AS `envoi_id`,`notification_objets`.`contenu` AS `contenu`,`notification_objets`.`id_objet` AS `id_objet`,`notification_objets`.`datenotification` AS `datenotification` from (`users` join `notification_objets`) where (`users`.`id` = `notification_objets`.`recev_id`) order by `notification_objets`.`datenotification` desc */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `listenotifications`
--

/*!50001 DROP VIEW IF EXISTS `listenotifications`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `listenotifications` AS select `notifications`.`id` AS `id`,`users`.`nom` AS `nom`,`users`.`postnom` AS `postnom`,`users`.`prenom` AS `prenom`,`users`.`email` AS `email`,`users`.`avatar` AS `avatar`,`users`.`telephone` AS `telephone`,`notifications`.`recev_id` AS `recev_id`,`notifications`.`envoi_id` AS `envoi_id`,`notifications`.`contenu` AS `contenu`,`notifications`.`datenotification` AS `datenotification` from (`users` join `notifications`) where (`users`.`id` = `notifications`.`recev_id`) order by `notifications`.`datenotification` desc */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `listeobjets`
--

/*!50001 DROP VIEW IF EXISTS `listeobjets`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_0900_ai_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`root`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `listeobjets` AS select `objets`.`id` AS `id`,`objets`.`id_type` AS `id_type`,`objets`.`iduser` AS `iduser`,`objets`.`marque` AS `marque`,`objets`.`model` AS `model`,`objets`.`numero_chassis` AS `numero_chassis`,`objets`.`immatriculation` AS `immatriculation`,`type_objets`.`description` AS `description` from (`objets` join `type_objets`) where (`type_objets`.`id` = `objets`.`id_type`) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-02-24 17:18:38
