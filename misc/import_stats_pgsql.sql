DROP TABLE IF EXISTS get5_stats_players;
DROP TABLE IF EXISTS get5_stats_maps;
DROP TABLE IF EXISTS get5_stats_matches;

CREATE TABLE IF NOT EXISTS get5_stats_matches
(
    matchid     BIGINT UNIQUE NOT NULL,
    start_time  TIMESTAMP     NOT NULL,
    end_time    TIMESTAMP,
    winner      VARCHAR(16)   NOT NULL DEFAULT '',
    series_type VARCHAR(64)   NOT NULL DEFAULT '',
    team1_name  VARCHAR(64)   NOT NULL DEFAULT '',
    team1_score INTEGER       NOT NULL DEFAULT 0,
    team2_name  VARCHAR(64)   NOT NULL DEFAULT '',
    team2_score INTEGER       NOT NULL DEFAULT 0,
    server_id   BIGINT        NOT NULL DEFAULT 0,
    CONSTRAINT get5_stats_matches_pk PRIMARY KEY (matchid)
);

CREATE SEQUENCE get5_stats_matches_matchid_seq;

ALTER TABLE get5_stats_matches
    ALTER COLUMN matchid SET DEFAULT nextval('get5_stats_matches_matchid_seq');

ALTER SEQUENCE get5_stats_matches_matchid_seq OWNED BY get5_stats_matches.matchid;

CREATE TABLE IF NOT EXISTS get5_stats_maps
(
    matchid     BIGINT      NOT NULL,
    mapnumber   INTEGER     NOT NULL,
    start_time  TIMESTAMP   NOT NULL,
    end_time    TIMESTAMP,
    winner      VARCHAR(16) NOT NULL DEFAULT '',
    mapname     VARCHAR(64) NOT NULL DEFAULT '',
    team1_score INTEGER     NOT NULL DEFAULT 0,
    team2_score INTEGER     NOT NULL DEFAULT 0,
    CONSTRAINT get5_stats_maps_pk PRIMARY KEY (matchid, mapnumber),
    CONSTRAINT get5_stats_maps_matchid FOREIGN KEY (matchid) REFERENCES get5_stats_matches (matchid)
);

CREATE TABLE IF NOT EXISTS get5_stats_players
(
    matchid            BIGINT      NOT NULL,
    mapnumber          INTEGER     NOT NULL,
    steamid64          VARCHAR(64) NOT NULL DEFAULT '',
    team               VARCHAR(16) NOT NULL DEFAULT '',
    rounds_played      INTEGER     NOT NULL DEFAULT 0,
    name               VARCHAR(64) NOT NULL DEFAULT '',
    kills              INTEGER     NOT NULL DEFAULT 0,
    deaths             INTEGER     NOT NULL DEFAULT 0,
    assists            INTEGER     NOT NULL DEFAULT 0,
    flashbang_assists  INTEGER     NOT NULL DEFAULT 0,
    teamkills          INTEGER     NOT NULL DEFAULT 0,
    headshot_kills     INTEGER     NOT NULL DEFAULT 0,
    damage             INTEGER     NOT NULL DEFAULT 0,
    bomb_plants        INTEGER     NOT NULL DEFAULT 0,
    bomb_defuses       INTEGER     NOT NULL DEFAULT 0,
    v1                 INTEGER     NOT NULL DEFAULT 0,
    v2                 INTEGER     NOT NULL DEFAULT 0,
    v3                 INTEGER     NOT NULL DEFAULT 0,
    v4                 INTEGER     NOT NULL DEFAULT 0,
    v5                 INTEGER     NOT NULL DEFAULT 0,
    k2                 INTEGER     NOT NULL DEFAULT 0,
    k3                 INTEGER     NOT NULL DEFAULT 0,
    k4                 INTEGER     NOT NULL DEFAULT 0,
    k5                 INTEGER     NOT NULL DEFAULT 0,
    firstkill_t        INTEGER     NOT NULL DEFAULT 0,
    firstkill_ct       INTEGER     NOT NULL DEFAULT 0,
    firstdeath_t       INTEGER     NOT NULL DEFAULT 0,
    firstdeath_ct      INTEGER     NOT NULL DEFAULT 0,
    tradekill          INTEGER     NOT NULL DEFAULT 0,
    kast               INTEGER     NOT NULL DEFAULT 0,
    contribution_score INTEGER     NOT NULL DEFAULT 0,
    mvp                INTEGER     NOT NULL DEFAULT 0,
    CONSTRAINT get5_stats_players_pk PRIMARY KEY (matchid, mapnumber, steamid64),
    CONSTRAINT get5_stats_players_matchid FOREIGN KEY (matchid) REFERENCES get5_stats_matches,
    CONSTRAINT get5_stats_players_mapnumber FOREIGN KEY (matchid, mapnumber) REFERENCES get5_stats_maps (matchid, mapnumber)
);

CREATE FUNCTION save_stats_player(matchId BIGINT, mapnumber INTEGER, steamid64 VARCHAR, team VARCHAR,
                                  rounds_played INTEGER, name VARCHAR, kills INTEGER, deaths INTEGER, assists INTEGER,
                                  flashbang_assists INTEGER, teamkills INTEGER, headshot_kills INTEGER, damage INTEGER,
                                  bomb_plants INTEGER, bomb_defuses INTEGER, v1 INTEGER, v2 INTEGER, v3 INTEGER,
                                  v4 INTEGER, v5 INTEGER, k2 INTEGER, k3 INTEGER, k4 INTEGER, k5 INTEGER,
                                  firstkill_t INTEGER, firstkill_ct INTEGER, firstdeath_t INTEGER,
                                  firstdeath_ct INTEGER, tradekill INTEGER, kast integer, contribution_score INTEGER,
                                  mvp INTEGER) RETURNS VOID AS
$$
BEGIN
    LOOP
        UPDATE get5_stats_players statsPlayers
        SET rounds_played      = save_stats_player.rounds_played,
            kills              = save_stats_player.kills,
            deaths             = save_stats_player.deaths,
            assists            = save_stats_player.assists,
            flashbang_assists  = save_stats_player.flashbang_assists,
            teamkills          = save_stats_player.teamkills,
            headshot_kills     = save_stats_player.headshot_kills,
            damage             = save_stats_player.damage,
            bomb_plants        = save_stats_player.bomb_plants,
            bomb_defuses       = save_stats_player.bomb_defuses,
            v1                 = save_stats_player.v1,
            v2                 = save_stats_player.v2,
            v3                 = save_stats_player.v3,
            v4                 = save_stats_player.v4,
            v5                 = save_stats_player.v5,
            k2                 = save_stats_player.k2,
            k3                 = save_stats_player.k3,
            k4                 = save_stats_player.k4,
            k5                 = save_stats_player.k5,
            firstkill_t        = save_stats_player.firstkill_t,
            firstkill_ct       = save_stats_player.firstkill_ct,
            firstdeath_t       = save_stats_player.firstdeath_t,
            firstdeath_ct      = save_stats_player.firstdeath_ct,
            tradekill          = save_stats_player.tradekill,
            kast               = save_stats_player.kast,
            contribution_score = save_stats_player.contribution_score,
            mvp                = save_stats_player.mvp
        WHERE statsPlayers.matchid = save_stats_player.matchid
          AND statsPlayers.mapnumber = save_stats_player.mapnumber
          AND statsPlayers.steamid64 = save_stats_player.steamid64;
        IF found THEN
            RETURN;
        END IF;
        BEGIN
            INSERT INTO get5_stats_players(matchid, mapnumber, steamid64, team, rounds_played, name, kills, deaths,
                                           assists, flashbang_assists, teamkills, headshot_kills, damage, bomb_plants,
                                           bomb_defuses, v1, v2, v3, v4, v5, k2, k3, k4, k5, firstkill_t, firstkill_ct,
                                           firstdeath_t, firstdeath_ct, tradekill, kast, contribution_score, mvp)
            VALUES (save_stats_player.matchid, save_stats_player.mapnumber, save_stats_player.steamid64,
                    save_stats_player.team, save_stats_player.rounds_played, save_stats_player.name,
                    save_stats_player.kills, save_stats_player.deaths, save_stats_player.assists,
                    save_stats_player.flashbang_assists, save_stats_player.teamkills, save_stats_player.headshot_kills,
                    save_stats_player.damage, save_stats_player.bomb_plants, save_stats_player.bomb_defuses,
                    save_stats_player.v1, save_stats_player.v2, save_stats_player.v3, save_stats_player.v4,
                    save_stats_player.v5, save_stats_player.k2, save_stats_player.k3, save_stats_player.k4,
                    save_stats_player.k5, save_stats_player.firstkill_t, save_stats_player.firstkill_ct,
                    save_stats_player.firstdeath_t, save_stats_player.firstdeath_ct, save_stats_player.tradekill,
                    save_stats_player.kast, save_stats_player.contribution_score, save_stats_player.mvp);
            RETURN;
        EXCEPTION
            WHEN unique_violation THEN
        END;
    END LOOP;
END;
$$
    LANGUAGE plpgsql;
