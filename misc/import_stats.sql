--
-- Table structure for table `get5_stats_maps`
--

DROP TABLE IF EXISTS `get5_stats_maps`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `get5_stats_maps` (
  `matchid` int(10) unsigned NOT NULL,
  `mapnumber` smallint(5) unsigned NOT NULL,
  `start_time` datetime NOT NULL,
  `end_time` datetime,
  `winner` varchar(16) NOT NULL DEFAULT '',
  `mapname` varchar(64) NOT NULL DEFAULT '',
  `team1_score` smallint(5) unsigned NOT NULL DEFAULT '0',
  `team2_score` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`matchid`,`mapnumber`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `get5_stats_maps`
--

LOCK TABLES `get5_stats_maps` WRITE;
/*!40000 ALTER TABLE `get5_stats_maps` DISABLE KEYS */;
/*!40000 ALTER TABLE `get5_stats_maps` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `get5_stats_matches`
--

DROP TABLE IF EXISTS `get5_stats_matches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `get5_stats_matches` (
  `matchid` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `start_time` datetime NOT NULL,
  `end_time` datetime,
  `winner` varchar(16) NOT NULL DEFAULT '',
  `series_type` varchar(64) NOT NULL DEFAULT '',
  `team1_name` varchar(64) NOT NULL DEFAULT '',
  `team1_score` smallint(5) unsigned NOT NULL DEFAULT '0',
  `team2_name` varchar(64) NOT NULL DEFAULT '',
  `team2_score` smallint(5) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`matchid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `get5_stats_matches`
--

LOCK TABLES `get5_stats_matches` WRITE;
/*!40000 ALTER TABLE `get5_stats_matches` DISABLE KEYS */;
/*!40000 ALTER TABLE `get5_stats_matches` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `get5_stats_players`
--

DROP TABLE IF EXISTS `get5_stats_players`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `get5_stats_players` (
  `matchid` int(10) unsigned NOT NULL,
  `mapnumber` smallint(5) unsigned NOT NULL,
  `steamid64` varchar(32) NOT NULL,
  `team` varchar(16) NOT NULL DEFAULT '',
  `rounds_played` smallint(5) unsigned NOT NULL,
  `name` varchar(64) NOT NULL,
  `kills` smallint(5) unsigned NOT NULL,
  `deaths` smallint(5) unsigned NOT NULL,
  `assists` smallint(5) unsigned NOT NULL,
  `flashbang_assists` smallint(5) unsigned NOT NULL,
  `teamkills` smallint(5) unsigned NOT NULL,
  `headshot_kills` smallint(5) unsigned NOT NULL,
  `damage` int(10) unsigned NOT NULL,
  `bomb_plants` smallint(5) unsigned NOT NULL,
  `bomb_defuses` smallint(5) unsigned NOT NULL,
  `v1` smallint(5) unsigned NOT NULL,
  `v2` smallint(5) unsigned NOT NULL,
  `v3` smallint(5) unsigned NOT NULL,
  `v4` smallint(5) unsigned NOT NULL,
  `v5` smallint(5) unsigned NOT NULL,
  `2k` smallint(5) unsigned NOT NULL,
  `3k` smallint(5) unsigned NOT NULL,
  `4k` smallint(5) unsigned NOT NULL,
  `5k` smallint(5) unsigned NOT NULL,
  `firstkill_t` smallint(5) unsigned NOT NULL,
  `firstkill_ct` smallint(5) unsigned NOT NULL,
  `firstdeath_t` smallint(5) unsigned NOT NULL,
  `firstdeath_ct` smallint(5) unsigned NOT NULL,
  `contribution_score` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`matchid`,`mapnumber`,`steamid64`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `get5_stats_players`
--

LOCK TABLES `get5_stats_players` WRITE;
/*!40000 ALTER TABLE `get5_stats_players` DISABLE KEYS */;
/*!40000 ALTER TABLE `get5_stats_players` ENABLE KEYS */;
UNLOCK TABLES;

-- Dump completed on 2016-07-03  1:10:28
