CREATE TABLE IF NOT EXISTS get5_stats_matches (
	`matchid` INT UNSIGNED NOT NULL AUTO_INCREMENT,
	`winner` VARCHAR(16) NOT NULL DEFAULT '',
	`series_type` VARCHAR(64) NOT NULL DEFAULT '',
	`team1_name` VARCHAR(64) NOT NULL DEFAULT '',
	`team1_score` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	`team2_name` VARCHAR(64) NOT NULL DEFAULT '',
	`team2_score` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	PRIMARY KEY (`matchid`));

CREATE TABLE IF NOT EXISTS get5_stats_maps (
	`matchid` INT UNSIGNED NOT NULL,
	`mapnumber` SMALLINT UNSIGNED NOT NULL,
	`winner` VARCHAR(16) NOT NULL DEFAULT '',
	`mapname` VARCHAR(64) NOT NULL DEFAULT '',
	`team1_score` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	`team2_score` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
	PRIMARY KEY (`matchid`, `mapnumber`));

CREATE TABLE IF NOT EXISTS get5_stats_players (
	`matchid` INT unsigned NOT NULL,
	`mapnumber` SMALLINT unsigned NOT NULL,
	`steamid64` VARCHAR(32) NOT NULL,
	`team` VARCHAR(16) NOT NULL DEFAULT '',
	`rounds_played` SMALLINT unsigned NOT NULL,
	`name` VARCHAR(64) NOT NULL,
	`kills` SMALLINT NOT NULL,
	`deaths` SMALLINT NOT NULL,
	`assists` SMALLINT NOT NULL,
	`teamkills` SMALLINT NOT NULL,
	`headshot_kills` SMALLINT NOT NULL,
	`damage` INT NOT NULL,
	`bomb_plants` SMALLINT NOT NULL,
	`bomb_defuses` SMALLINT NOT NULL,
	`v1` SMALLINT NOT NULL,
	`v2` SMALLINT NOT NULL,
	`v3` SMALLINT NOT NULL,
	`v4` SMALLINT NOT NULL,
	`v5` SMALLINT NOT NULL,
	PRIMARY KEY (`matchid`, `mapnumber`, `steamid64`));
