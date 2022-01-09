#if defined _get5_included_
#endinput
#endif
#define _get5_included_

#include <json>  // github.com/clugg/sm-json
#include <cstrike>

enum Side {
  None = 0,
  Spectator = 1,
  Terrorists = 2,
  Counter_Terrorists = 3
};

#define MATCHTEAM_COUNT 4

enum MatchTeam {
  MatchTeam_Team1,
  MatchTeam_Team2,
  MatchTeam_TeamSpec,
  MatchTeam_TeamNone,
  MatchTeam_Count,
};

enum Get5State {
  Get5State_None,                          // no setup has taken place
  Get5State_PreVeto,                       // warmup, waiting for the veto
  Get5State_Veto,                          // warmup, doing the veto
  Get5State_Warmup,                        // setup done, waiting for players to ready up
  Get5State_KnifeRound,                    // in the knife round
  Get5State_WaitingForKnifeRoundDecision,  // waiting for a .stay/.swap command after the knife
  Get5State_GoingLive,                     // in the lo3 process
  Get5State_Live,                          // the match is live
  Get5State_PostGame,                      // postgame screen + waiting for GOTV to finish broadcast
};

enum PauseType {
  PauseType_Tactical = 1,  // Tactical Pause
  PauseType_Tech = 2,      // Technical pause
};

methodmap Get5Player < JSON_Object {

    property Side Side {
        public get() {
          return view_as<Side>(this.GetInt("side"));
        }

        public set(Side side) {
          this.SetInt("side", view_as<int>(side));
        }
    }

    public bool SetSteamId(const char[] value)
    {
        return this.SetString("steamid", value);
    }

    public bool GetSteamId(char[] buffer, const int maxSize) {
        return this.GetString("steamid", buffer, maxSize);
    }

    public Get5Player(const char[] steamId, Side side) {
        Get5Player self = view_as<Get5Player>(new JSON_Object());
        self.SetSteamId(steamId);
        self.Side = side;
        return self;
    }

    public bool IsEqualToPlayerId(const char[] id) {

        char ownId[64];
        this.GetSteamId(ownId, sizeof(ownId));

        return StrEqual(ownId, id);

    }
}

methodmap Get5Event < JSON_Object {

    public bool SetEvent(const char[] event)
    {
        return this.SetString("event", event);
    }

    public bool GetEvent(char[] buffer, const int maxSize) {
        return this.GetString("event", buffer, maxSize);
    }
}

methodmap Get5PlayerConnectedEvent < Get5Event {

  property Get5Player Player {
    public get() {
      return view_as<Get5Player>(this.GetObject("player"));
    }

    public set(Get5Player player) {
      this.SetObject("player", player);
    }
  }

  public Get5PlayerConnectedEvent(const Get5Player player) {
    Get5PlayerConnectedEvent self = view_as<Get5PlayerConnectedEvent>(new JSON_Object());
    self.SetEvent("player_connect");
    self.Player = player;
    return self;
  }
}

methodmap Get5PlayerDisconnectedEvent < Get5PlayerConnectedEvent {

  public Get5PlayerDisconnectedEvent(const Get5Player player) {
    Get5PlayerDisconnectedEvent self = view_as<Get5PlayerDisconnectedEvent>(new JSON_Object());
    self.SetEvent("player_disconnect");
    self.Player = player;
    return self;
  }
}

methodmap Get5MatchEvent < Get5Event {

    public bool SetMatchId(const char[] matchId)
    {
        return this.SetString("matchid", matchId);
    }

    public bool GetMatchId(char[] buffer, const int maxSize) {
        return this.GetString("matchid", buffer, maxSize);
    }

}

methodmap Get5MatchTeamEvent < Get5MatchEvent {

  property MatchTeam Team {
    public get() {
      return view_as<MatchTeam>(this.GetInt("team"));
    }

    public set(MatchTeam team) {
      this.SetInt("team", view_as<int>(team));
    }
  }
}

methodmap Get5MapEvent < Get5MatchEvent {

    public bool SetMapName(const char[] map) {
      return this.SetString("map_name", map);
    }

    public bool GetMapName(char[] buffer, const int maxSize) {
      return this.GetString("map_name", buffer, maxSize);
    }

    property int MapNumber {
        public get() {
          return this.GetInt("map_number");
        }

        public set(int mapNumber) {
          this.SetInt("map_number", mapNumber);
        }
    }
}

methodmap Get5MapTeamEvent < Get5MapEvent {

  property MatchTeam Team {
    public get() {
      return view_as<MatchTeam>(this.GetInt("team"));
    }

    public set(MatchTeam team) {
      this.SetInt("team", view_as<int>(team));
    }
  }
}

methodmap Get5RoundEvent < Get5MapEvent {

    property int RoundNumber {
        public get() {
          return this.GetInt("round_number");
        }

        public set(int roundNumber) {
          this.SetInt("round_number", roundNumber);
        }
    }
}

methodmap Get5TimedRoundEvent < Get5RoundEvent {

    property int RoundTime {
        public get() {
          return this.GetInt("round_time");
        }

        public set(int roundTime) {
          this.SetInt("round_time", roundTime);
        }
    }
}

methodmap Get5PlayerMapEvent < Get5MapEvent {

    property Get5Player Player {
        public get() {
          return view_as<Get5Player>(this.GetObject("player"));
        }

        public set(Get5Player player) {
          this.SetObject("player", player);
        }
    }
}

methodmap Get5PlayerRoundEvent < Get5RoundEvent {

    property Get5Player Player {
        public get() {
          return view_as<Get5Player>(this.GetObject("player"));
        }

        public set(Get5Player player) {
          this.SetObject("player", player);
        }
    }
}

methodmap Get5PlayerTimedRoundEvent < Get5TimedRoundEvent {

    property Get5Player Player {
        public get() {
          return view_as<Get5Player>(this.GetObject("player"));
        }

        public set(Get5Player player) {
          this.SetObject("player", player);
        }
    }
}

// MATCH CONFIG

methodmap Get5SeriesResultEvent < Get5MatchEvent {

  property MatchTeam Winner {
    public get() {
      return view_as<MatchTeam>(this.GetInt("winner"));
    }

    public set(MatchTeam winner) {
      this.SetInt("winner", view_as<int>(winner));
    }
  }

  property int Team1Score {
      public get() {
        return this.GetInt("team1_score");
      }

      public set(int score) {
        this.SetInt("team1_score", score);
      }
  }

  property int Team2Score {
      public get() {
        return this.GetInt("team2_score");
      }

      public set(int score) {
        this.SetInt("team2_score", score);
      }
  }

  public Get5SeriesResultEvent(const char[] matchId, MatchTeam winner, const int team1Score, const int team2Score) {
    Get5SeriesResultEvent self = view_as<Get5SeriesResultEvent>(new JSON_Object());
    self.SetEvent("series_end");
    self.SetMatchId(matchId);
    self.Winner = winner;
    self.Team1Score = team1Score;
    self.Team2Score = team2Score;
    return self;
  }

}

methodmap Get5PreloadMatchConfigEvent < Get5Event {

  public bool SetFilePath(const char[] filePath)
  {
     return this.SetString("file_path", filePath);
  }

  public bool GetFilePath(char[] buffer, const int maxSize) {
     return this.GetString("file_path", buffer, maxSize);
  }

  public Get5PreloadMatchConfigEvent(const char[] filePath) {
    Get5PreloadMatchConfigEvent self = view_as<Get5PreloadMatchConfigEvent>(new JSON_Object());
    self.SetEvent("preload_match_config");
    self.SetFilePath(filePath);
    return self;
  }

}

methodmap Get5LoadMatchConfigFailedEvent < Get5Event {


  public bool SetReason(const char[] reason)
  {
     return this.SetString("reason", reason);
  }

  public bool GetReason(char[] buffer, const int maxSize) {
     return this.GetString("reason", buffer, maxSize);
  }

  public Get5LoadMatchConfigFailedEvent(const char[] reason) {
    Get5LoadMatchConfigFailedEvent self = view_as<Get5LoadMatchConfigFailedEvent>(new JSON_Object());
    self.SetEvent("map_picked");
    self.SetReason(reason);
    return self;
  }

}

methodmap Get5MapSelectionEvent < Get5MatchTeamEvent {

    public bool SetMapName(const char[] map)
    {
        return this.SetString("map_name", map);
    }

    public bool GetMapName(char[] buffer, const int maxSize) {
        return this.GetString("map_name", buffer, maxSize);
    }

}

methodmap Get5MapPickedEvent < Get5MapSelectionEvent {

    property int MapNumber {
        public get() {
          return this.GetInt("map_number");
        }

        public set(int mapNumber) {
          this.SetInt("map_number", mapNumber);
        }
    }

  public Get5MapPickedEvent(const char[] matchId, const MatchTeam team, const char[] map, const int mapNumber) {
    Get5MapPickedEvent self = view_as<Get5MapPickedEvent>(new JSON_Object());
    self.SetEvent("map_picked");
    self.SetMatchId(matchId);
    self.Team = team;
    self.SetMapName(map);
    self.MapNumber = mapNumber;
    return self;
  }
}

methodmap Get5MapVetoedEvent < Get5MapSelectionEvent {

  public Get5MapVetoedEvent(const char[] matchId, const MatchTeam team, const char[] map) {
    Get5MapVetoedEvent self = view_as<Get5MapVetoedEvent>(new JSON_Object());
    self.SetEvent("map_vetoed");
    self.SetMatchId(matchId);
    self.Team = team;
    self.SetMapName(map);
    return self;
  }
}

methodmap Get5SidePickedEvent < Get5MapTeamEvent {

  property Side Side {
      public get() {
        return view_as<Side>(this.GetInt("side"));
      }

      public set(Side side) {
        this.SetInt("side", view_as<int>(side));
      }
  }

  public Get5SidePickedEvent(const char[] matchId, const int mapNumber, const char[] mapName, const MatchTeam team, const Side side) {
    Get5SidePickedEvent self = view_as<Get5SidePickedEvent>(new JSON_Object());
    self.SetEvent("side_picked");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.SetMapName(mapName);
    self.Team = team;
    self.Side = side;
    return self;
  }
}

// MATCH STATE
methodmap Get5MapResultEvent < Get5MapEvent {

  property MatchTeam Winner {
    public get() {
      return view_as<MatchTeam>(this.GetInt("winner"));
    }

    public set(MatchTeam winner) {
      this.SetInt("winner", view_as<int>(winner));
    }
  }

  property int Team1Score {
      public get() {
        return this.GetInt("team1_score");
      }

      public set(int score) {
        this.SetInt("team1_score", score);
      }
  }

  property int Team2Score {
      public get() {
        return this.GetInt("team2_score");
      }

      public set(int score) {
        this.SetInt("team2_score", score);
      }
  }

  public Get5MapResultEvent(const char[] matchId, const int mapNumber, const char[] mapName, const MatchTeam winner, int team1Score, int team2Score) {
    Get5MapResultEvent self = view_as<Get5MapResultEvent>(new JSON_Object());
    self.SetEvent("map_result");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.SetMapName(mapName);
    self.Winner = winner;
    self.Team1Score = team1Score;
    self.Team2Score = team2Score;
    return self;
  }

}

methodmap Get5GameStateChangedEvent < Get5Event {

  property Get5State NewState {
      public get() {
        return view_as<Get5State>(this.GetInt("new_state"));
      }

      public set(Get5State state) {
        this.SetInt("new_state", view_as<int>(state));
      }
  }

  property Get5State OldState {
      public get() {
        return view_as<Get5State>(this.GetInt("old_state"));
      }

      public set(Get5State state) {
        this.SetInt("old_state", view_as<int>(state));
      }
  }

  public Get5GameStateChangedEvent(const Get5State newState, const Get5State oldState) {
    Get5GameStateChangedEvent self = view_as<Get5GameStateChangedEvent>(new JSON_Object());
    self.SetEvent("game_state_changed");
    self.NewState = newState;
    self.OldState = oldState;
    return self;
  }

}

methodmap Get5RoundStatsUpdatedEvent < Get5MatchEvent {

  public Get5RoundStatsUpdatedEvent(const char[] matchId) {
    Get5RoundStatsUpdatedEvent self = view_as<Get5RoundStatsUpdatedEvent>(new JSON_Object());
    self.SetEvent("stats_updated");
    self.SetMatchId(matchId);
    return self;
  }

}

methodmap Get5DemoFinishedEvent < Get5MapEvent {

    public bool SetFileName(const char[] filename)
    {
        return this.SetString("filename", filename);
    }

    public bool GetFileName(char[] buffer, const int maxSize) {
        return this.GetString("filename", buffer, maxSize);
    }

  public Get5DemoFinishedEvent(const char[] matchId, const int mapNumber, const char[] filename) {
    Get5DemoFinishedEvent self = view_as<Get5DemoFinishedEvent>(new JSON_Object());
    self.SetEvent("demo_finished");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.SetFileName(filename);
    return self;
  }

}

methodmap Get5KnifeRoundWonEvent < Get5MapTeamEvent {

    property Side Side {
      public get() {
        return view_as<Side>(this.GetInt("side"));
      }

      public set(Side side) {
        this.SetInt("side", view_as<int>(side));
      }
    }

    property bool Swapped {
      public get() {
        return this.GetBool("swapped");
      }

      public set(bool swapped) {
        this.SetBool("swapped", swapped);
      }
    }

    public Get5KnifeRoundWonEvent(const char[] matchId, int mapNumber, const MatchTeam winner, const Side side, const bool swapped) {
    Get5KnifeRoundWonEvent self = view_as<Get5KnifeRoundWonEvent>(new JSON_Object());
    self.SetEvent("knife_won");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.Team = winner;
    self.Side = side;
    self.Swapped = swapped;
    return self;
  }

}


methodmap Get5MatchPausedEvent < Get5MatchTeamEvent {

  property PauseType PauseType {
      public get() {
        return view_as<PauseType>(this.GetInt("pause_type"));
      }

      public set(PauseType state) {
        this.SetInt("pause_type", view_as<int>(PauseType));
      }
  }

  public Get5MatchPausedEvent(const char[] matchId, const MatchTeam team, const PauseType pauseType) {
    Get5MatchPausedEvent self = view_as<Get5MatchPausedEvent>(new JSON_Object());
    self.SetEvent("game_paused");
    self.SetMatchId(matchId);
    self.Team = team;
    self.PauseType = pauseType;
    return self;
  }

}

methodmap Get5MatchUnpausedEvent < Get5MatchTeamEvent {

  public Get5MatchUnpausedEvent(const char[] matchId, const MatchTeam team) {
    Get5MatchUnpausedEvent self = view_as<Get5MatchUnpausedEvent>(new JSON_Object());
    self.SetEvent("game_unpaused");
    self.SetMatchId(matchId);
    self.Team = team;
    return self;
  }

}

methodmap Get5SeriesStartedEvent < Get5MatchEvent {

    public bool SetTeam1Name(const char[] value)
    {
        return this.SetString("team1_name", value);
    }

    public bool GetTeam1Name(char[] buffer, const int maxSize) {
        return this.GetString("team1_name", buffer, maxSize);
    }

    public bool SetTeam2Name(const char[] value)
    {
        return this.SetString("team2_name", value);
    }

    public bool GetTeam2Name(char[] buffer, const int maxSize) {
        return this.GetString("team2_name", buffer, maxSize);
    }

  public Get5SeriesStartedEvent(const char[] matchId, const char[] team1Name, const char[] team2Name) {
        Get5SeriesStartedEvent self = view_as<Get5SeriesStartedEvent>(new JSON_Object());
        self.SetEvent("series_start");
        self.SetMatchId(matchId);
        self.SetTeam1Name(team1Name);
        self.SetTeam2Name(team2Name);
        return self;
    }
}

methodmap Get5BackupRestoredEvent < Get5MapEvent {

  public Get5BackupRestoredEvent(const char[] matchId, const int mapNumber) {
        Get5BackupRestoredEvent self = view_as<Get5BackupRestoredEvent>(new JSON_Object());
        self.SetEvent("backup_loaded");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        return self;
    }
}

methodmap Get5RoundStartedEvent < Get5RoundEvent {

  public Get5RoundStartedEvent(const char[] matchId, const int mapNumber, const int roundNumber) {
        Get5RoundStartedEvent self = view_as<Get5RoundStartedEvent>(new JSON_Object());
        self.SetEvent("round_start");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        return self;
    }
}

methodmap Get5GoingLiveEvent < Get5MapEvent {

  public Get5GoingLiveEvent(const char[] matchId, const int mapNumber) {
        Get5GoingLiveEvent self = view_as<Get5GoingLiveEvent>(new JSON_Object());
        self.SetEvent("going_live");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        return self;
    }
}

methodmap Get5RoundEndedEvent < Get5TimedRoundEvent {

  // Note that reason is decremented by 1 to match the values defined at https://github.com/alliedmodders/sourcemod/blob/master/plugins/include/cstrike.inc
  // CSGO increments these by 1 for some reason.
  property CSRoundEndReason Reason {
      public get() {
        return view_as<CSRoundEndReason>(this.GetInt("reason"));
      }

      public set(CSRoundEndReason reason) {
        this.SetInt("reason", view_as<int>(reason));
      }
  }

  property Side Winner {
      public get() {
        return view_as<Side>(this.GetInt("winner"));
      }

      public set(Side winner) {
        this.SetInt("winner", view_as<int>(winner));
      }
  }

  property int Team1Score {
      public get() {
        return this.GetInt("team1_score");
      }

      public set(int score) {
        this.SetInt("team1_score", score);
      }
  }

  property int Team2Score {
      public get() {
        return this.GetInt("team2_score");
      }

      public set(int score) {
        this.SetInt("team2_score", score);
      }
  }

  public Get5RoundEndedEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const CSRoundEndReason reason, const Side winner, const int team1Score, const int team2Score) {
        Get5RoundEndedEvent self = view_as<Get5RoundEndedEvent>(new JSON_Object());
        self.SetEvent("round_end");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        self.RoundTime = roundTime;
        self.Reason = reason;
        self.Winner = winner
        self.Team1Score = team1Score;
        self.Team2Score = team2Score;
        return self;
    }
}

// All other events

methodmap Get5PlayerSayEvent < Get5PlayerTimedRoundEvent {

  public bool SetMessage(const char[] message)
  {
    return this.SetString("message", message);
  }

  public bool GetMessage(char[] buffer, const int maxSize) {
    return this.GetString("message", buffer, maxSize);
  }

  public bool SetArguments(const char[] args)
  {
    return this.SetString("arguments", args);
  }

  public bool GetArguments(char[] buffer, const int maxSize) {
    return this.GetString("arguments", buffer, maxSize);
  }

  public Get5PlayerSayEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player, const char[] message, const char[] arguments) {
        Get5PlayerSayEvent self = view_as<Get5PlayerSayEvent>(new JSON_Object());
        self.SetEvent("player_say");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        self.RoundTime = roundTime;
        self.SetMessage(message);
        self.SetArguments(arguments);
        return self;
    }
}

methodmap Get5RoundMVPEvent < Get5PlayerRoundEvent {

  // There doesn't seem to be an enum for MVP reason, so we go with the plain integer.
  property int Reason {
      public get() {
        return this.GetInt("reason");
      }

      public set(int reason) {
        this.SetInt("reason", reason);
      }
  }

  public Get5RoundMVPEvent(const char[] matchId, const int mapNumber, const int roundNumber, const Get5Player player, const int reason) {
        Get5RoundMVPEvent self = view_as<Get5RoundMVPEvent>(new JSON_Object());
        self.SetEvent("round_mvp");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        self.Player = player;
        self.Reason = reason;
        return self;
    }
}

methodmap Get5AssisterObject < JSON_Object {

  property Get5Player Player {
      public get() {
        return view_as<Get5Player>(this.GetObject("player"));
      }

      public set(Get5Player player) {
        this.SetObject("player", player);
      }
  }

  property bool FriendlyFire {
      public get() {
        return this.GetBool("friendly_fire");
      }

      public set(bool friendlyFire) {
        this.SetBool("friendly_fire", friendlyFire);
      }

  }

  property bool FlashAssist {
      public get() {
        return this.GetBool("flash_assist");
      }

      public set(bool flashAssist) {
        this.SetBool("flash_assist", flashAssist);
      }

  }

  public Get5AssisterObject(const Get5Player player, bool flashAssist, bool friendlyFire) {
    Get5AssisterObject self = view_as<Get5AssisterObject>(new JSON_Object());
    self.Player = player;
    self.FlashAssist = flashAssist;
    self.FriendlyFire = friendlyFire;
    return self;
  }

}

methodmap Get5PlayerWeaponEvent < Get5PlayerTimedRoundEvent {

    public bool SetWeapon(const char[] value)
    {
        return this.SetString("weapon", value);
    }

    public bool GetWeapon(char[] buffer, const int maxSize) {
        return this.GetString("weapon", buffer, maxSize);
    }

    property CSWeaponID WeaponId {
        public get() {
          return view_as<CSWeaponID>(this.GetInt("weapon_id"));
        }

        public set(CSWeaponID weaponId) {
          this.SetInt("weapon_id", view_as<int>(weaponId));
        }
    }
}

methodmap Get5PlayerDeathEvent < Get5PlayerWeaponEvent {

  property bool Headshot {
      public get() {
        return this.GetBool("headshot");
      }

      public set(bool headshot) {
        this.SetBool("headshot", headshot);
      }
  }

  property bool ThruSmoke {
      public get() {
        return this.GetBool("thru_smoke");
      }

      public set(bool thruSmoke) {
        this.SetBool("thru_smoke", thruSmoke);
      }
  }

  property int Penetrated {
      public get() {
        return this.GetInt("penetrated");
      }

      public set(int penetrated) {
        this.SetInt("penetrated", penetrated);
      }
  }

  property bool AttackerBlind {
      public get() {
        return this.GetBool("attacker_blind");
      }

      public set(bool blind) {
        this.SetBool("attacker_blind", blind);
      }
  }

  property bool NoScope {
      public get() {
        return this.GetBool("no_scope");
      }

      public set(bool noScope) {
        this.SetBool("no_scope", noScope);
      }
  }

  property bool Suicide {
      public get() {
        return this.GetBool("suicide");
      }

      public set(bool suicide) {
        this.SetBool("suicide", suicide);
      }
  }

  property bool FriendlyFire {
      public get() {
        return this.GetBool("friendly_fire");
      }

      public set(bool friendlyFire) {
        this.SetBool("friendly_fire", friendlyFire);
      }
  }

  property Get5Player Attacker {
      public get() {
        return view_as<Get5Player>(this.GetObject("attacker"));
      }

      public set(Get5Player attacker) {
        this.SetObject("attacker", attacker);
      }
  }

  property Get5AssisterObject Assist {
      public get() {
        return view_as<Get5AssisterObject>(this.GetObject("assist"));
      }

      public set(Get5AssisterObject assister) {
        this.SetObject("assist", assister);
      }
  }

  // Use this before accessing the Assist object, as it will raise an exception if null.
  public bool HasAssist() {
    return this.GetObject("assist") != null;  
  }

  public Get5PlayerDeathEvent(
    const char[] matchId,
    const int mapNumber,
    const int roundNumber,
    const int roundTime,
    const CSWeaponID weaponId,
    const char[] weapon,
    const Get5Player victim,
    const Get5Player attacker,
    const bool headshot,
    const bool friendlyFire,
    const bool thruSmoke,
    const bool noScope,
    const bool attackerBlind,
    const bool suicide,
    const int penetrated
    ) {

        Get5PlayerDeathEvent self = view_as<Get5PlayerDeathEvent>(new JSON_Object());
        self.SetEvent("player_death");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        self.RoundTime = roundTime;
        self.WeaponId = weaponId;
        self.SetWeapon(weapon);
        self.Player = victim;
        self.Attacker = attacker;
        self.Headshot = headshot;
        self.FriendlyFire = friendlyFire;
        self.ThruSmoke = thruSmoke;
        self.NoScope = noScope;
        self.AttackerBlind = attackerBlind;
        self.Suicide = suicide;
        self.Penetrated = penetrated;

        // set assist to null initially
        self.SetObject("assist", null);
        return self;

    }
}

// GRENADES
methodmap Get5GrenadeThrownEvent < Get5PlayerWeaponEvent {

    public Get5GrenadeThrownEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player, const CSWeaponID weaponId, const char[] weapon) {
        Get5GrenadeThrownEvent self = view_as<Get5GrenadeThrownEvent>(new JSON_Object());
        self.SetEvent("grenade_thrown");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        self.RoundTime = roundTime;
        self.Player = player;
        self.WeaponId = weaponId;
        self.SetWeapon(weapon);
        return self;
    }
}

methodmap Get5VictimGrenadeEvent < Get5PlayerWeaponEvent {

    // Array of either Get5DamageGrenadeVictim or Get5BlindedGrenadeVictim
    property JSON_Array Victims {
        public get() {
          return view_as<JSON_Array>(this.GetObject("victims"));
        }

        public set(JSON_Array victims) {
          this.SetObject("victims", victims);
        }
    }
}

methodmap Get5SmokeGrenadeEvent < Get5PlayerWeaponEvent {

    property bool ExtinguishedMolotov {
        public get() {
          return this.GetBool("extinguished_molotov");
        }

        public set(bool extinguishedMolotov) {
          this.SetBool("extinguished_molotov", extinguishedMolotov);
        }
    }

    public Get5SmokeGrenadeEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player) {
        Get5SmokeGrenadeEvent self = view_as<Get5SmokeGrenadeEvent>(new JSON_Object());
        self.SetEvent("smokegrenade_detonated");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        self.RoundTime = roundTime;
        self.Player = player;
        self.WeaponId = CSWeapon_SMOKEGRENADE;
        self.SetWeapon("smokegrenade");
        self.ExtinguishedMolotov = false;
        return self;
    }
}

methodmap Get5HEGrenadeEvent < Get5VictimGrenadeEvent {

    public Get5HEGrenadeEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player) {
        Get5HEGrenadeEvent self = view_as<Get5HEGrenadeEvent>(new JSON_Object());
        self.SetEvent("hegrenade_detonated");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        self.RoundTime = roundTime;
        self.Player = player;
        self.WeaponId = CSWeapon_HEGRENADE;
        self.SetWeapon("hegrenade");
        self.Victims = new JSON_Array();
        return self;
    }
}

methodmap Get5FlashbangGrenadeEvent < Get5VictimGrenadeEvent {

    public Get5FlashbangGrenadeEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player) {
        Get5FlashbangGrenadeEvent self = view_as<Get5FlashbangGrenadeEvent>(new JSON_Object());
        self.SetEvent("flashbang_detonated");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        self.RoundTime = roundTime;
        self.Player = player;
        self.WeaponId = CSWeapon_FLASHBANG;
        self.SetWeapon("flashbang");
        self.Victims = new JSON_Array();
        return self;
    }
}

methodmap Get5DecoyGrenadeEvent < Get5VictimGrenadeEvent {

    // Because RoundTime is when the grenade started making noise, we need a separate time for detonation.
    property int DetonatedTime {
        public get() {
          return this.GetInt("round_time_detonated");
        }

        public set(int roundTimeDetonated) {
          this.SetInt("round_time_detonated", roundTimeDetonated);
        }
    }

    public Get5DecoyGrenadeEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player) {
        Get5DecoyGrenadeEvent self = view_as<Get5DecoyGrenadeEvent>(new JSON_Object());
        self.SetEvent("decoygrenade_ended");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        self.RoundTime = roundTime;
        self.Player = player;
        self.WeaponId = CSWeapon_DECOY;
        self.SetWeapon("decoy");
        self.Victims = new JSON_Array();
        self.DetonatedTime = 0;
        return self;
    }
}

methodmap Get5MolotovEvent < Get5VictimGrenadeEvent {

    // RoundTime is when the molotov detonated.
    property int EndTime {
        public get() {
          return this.GetInt("round_time_ended");
        }

        public set(int endTime) {
          this.SetInt("round_time_ended", endTime);
          this.SetInt("duration", endTime - this.RoundTime);
        }
    }

    property bool Extinguished {
        public get() {
          return this.GetBool("extinguished");
        }

        public set(bool extinguished) {
          this.SetBool("extinguished", extinguished);
        }
    }

    public Get5MolotovEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player) {
        Get5MolotovEvent self = view_as<Get5MolotovEvent>(new JSON_Object());
        self.SetEvent("molotov_ended");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        self.RoundTime = roundTime;
        self.Player = player;
        self.WeaponId = CSWeapon_MOLOTOV; // Sourcemod does not give us the info required to distinguish between molly and firebomb
        self.SetWeapon("molotov");
        self.Victims = new JSON_Array();
        self.Extinguished = false;
        self.EndTime = 0;
        return self;
    }
}

methodmap Get5GrenadeVictim < JSON_Object {

    property Get5Player Player {
        public get() {
          return view_as<Get5Player>(this.GetObject("player"));
        }

        public set(Get5Player player) {
          this.SetObject("player", player);
        }
    }

    property bool FriendlyFire {
        public get() {
          return this.GetBool("friendly_fire");
        }

        public set(bool friendlyFire) {
          this.SetBool("friendly_fire", friendlyFire);
        }
    }

}

methodmap Get5DamageGrenadeVictim < Get5GrenadeVictim {

    property int Damage {
        public get() {
          return this.GetInt("damage");
        }

        public set(int damage) {
          this.SetInt("damage", damage);
        }
    }

    public Get5DamageGrenadeVictim(const Get5Player player, const bool friendlyFire, const int damage) {
        Get5DamageGrenadeVictim self = view_as<Get5DamageGrenadeVictim>(new JSON_Object());
        self.Player = player
        self.FriendlyFire = friendlyFire;
        self.Damage = damage;
        return self;
    }
}

methodmap Get5BlindedGrenadeVictim < Get5GrenadeVictim {

    property float BlindDuration {
        public get() {
          return this.GetFloat("blind_duration");
        }

        public set(float blindDuration) {
          this.SetFloat("blind_duration", blindDuration);
        }
    }

    public Get5BlindedGrenadeVictim(const Get5Player player, const bool friendlyFire, const float blindDuration) {
        Get5BlindedGrenadeVictim self = view_as<Get5BlindedGrenadeVictim>(new JSON_Object());
        self.Player = player
        self.FriendlyFire = friendlyFire;
        self.BlindDuration = blindDuration;
        return self;
    }
}

// BOMB

methodmap Get5BombEvent < Get5TimedRoundEvent {

    property int Site {
        public get() {
          return this.GetInt("site");
        }

        public set(int site) {
          this.SetInt("site", site);
        }
    }

}

methodmap Get5PlayerBombEvent < Get5PlayerTimedRoundEvent {

    property int Site {
        public get() {
          return this.GetInt("site");
        }

        public set(int site) {
          this.SetInt("site", site);
        }
    }

}

methodmap Get5BombPlantedEvent < Get5PlayerBombEvent {

    public Get5BombPlantedEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player, const int site) {
        Get5BombPlantedEvent self = view_as<Get5BombPlantedEvent>(new JSON_Object());
        self.SetEvent("bomb_planted");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        self.RoundTime = roundTime;
        self.Player = player;
        self.Site = site;
        return self;
    }
}

methodmap Get5BombExplodedEvent < Get5BombEvent {

    public Get5BombExplodedEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const int site) {
        Get5BombExplodedEvent self = view_as<Get5BombExplodedEvent>(new JSON_Object());
        self.SetEvent("bomb_exploded");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        self.RoundTime = roundTime;
        self.Site = site;
        return self;
    }
}

methodmap Get5BombDefusedEvent < Get5PlayerBombEvent {

    property int TimeRemaining {
        public get() {
          return this.GetInt("bomb_time_remaining");
        }

        public set(int time) {
          this.SetInt("bomb_time_remaining", time);
        }
    }

    public Get5BombDefusedEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player, const int site, const int timeRemaining) {
        Get5BombDefusedEvent self = view_as<Get5BombDefusedEvent>(new JSON_Object());
        self.SetEvent("bomb_defused");
        self.SetMatchId(matchId);
        self.MapNumber = mapNumber;
        self.RoundNumber = roundNumber;
        self.RoundTime = roundTime;
        self.Player = player;
        self.Site = site;
        self.TimeRemaining = timeRemaining;
        return self;
    }
}

enum MatchSideType {
  MatchSideType_Standard,     // Team that doesn't pick map gets side choice, leftovers go to knife
                              // rounds
  MatchSideType_AlwaysKnife,  // All maps use a knife round to pick sides
  MatchSideType_NeverKnife,   // Team 1 always starts CT
};

enum SideChoice {
  SideChoice_Team1CT,     // Team 1 will start on CT
  SideChoice_Team1T,      // Team 1 will start on T
  SideChoice_KnifeRound,  // There will be a knife round to choose sides
};

// Called each get5-event with JSON formatted event text.
forward void Get5_OnEvent(const char[] eventJson);

// Called when a series is first setup.
// Note: Do not rely on the state of any cvars at this point.
// Also: matchId is an empty string at this stage if not defined in the match config.
forward void Get5_OnSeriesInit(const Get5SeriesStartedEvent event);

// Called each time in a match when a map is going live.
// The mapNumber parameter starts at 0.
forward void Get5_OnGoingLive(const Get5GoingLiveEvent event);

// Called whenever the gamestate phase is changed.
forward void Get5_OnGameStateChanged(const Get5GameStateChangedEvent event);

forward void Get5_OnGrenadeThrown(const Get5GrenadeThrownEvent event);

// Called when the stats for the last round have been updated.
forward void Get5_OnRoundStatsUpdated(const Get5RoundStatsUpdatedEvent event);

// Called at the end of a map in a series.
forward void Get5_OnMapResult(const Get5MapResultEvent event);

// Called at the end of a full match.
// Note: both Get5_OnMapResult and Get5_OnSeriesResult are called on the last map of a series.
forward void Get5_OnSeriesResult(const Get5SeriesResultEvent event);

forward void Get5_OnPreLoadMatchConfig(const Get5PreloadMatchConfigEvent event);

// Called when a match config fails to load.
forward void Get5_OnLoadMatchConfigFailed(const Get5LoadMatchConfigFailedEvent event);

// Called when a team vetoes a map.
forward void Get5_OnMapVetoed(const Get5MapVetoedEvent event);

// Called when a team has won the knife round and picked a starting side.
forward void Get5_OnKnifeRoundWon(const Get5KnifeRoundWonEvent event); 

// Called when a team selects a map.
// The team parameter will be MatchTeam_TeamNone if the map was selected as the last remaining map
// and not by one of the teams specifically.
forward void Get5_OnMapPicked(const Get5MapPickedEvent event);

// Called when a player is elected the MVP of the round.
forward void Get5_OnPlayerBecameMVP(const Get5RoundMVPEvent event);

// Called when a player dies in a match, including from suicide and team kills.
forward void Get5_OnPlayerDeath(const Get5PlayerDeathEvent event);

// Called when a player types something in the chat, including commands.
forward void Get5_OnPlayerSay(const Get5PlayerSayEvent event);

// Called when a round starts (after freezetime ends!)
forward void Get5_OnRoundStart(const Get5RoundStartedEvent event);

// Called when a flashbang detonates (after collecting victim info)
forward void Get5_OnFlashBangDetonated(const Get5FlashbangGrenadeEvent event);

// Called when a decoy grenade detonates - or if the round ends (after collecting victim info).
forward void Get5_OnDecoyEnded(const Get5DecoyGrenadeEvent event);

// Called when an HE grenade goes off (after collecting victim info).
forward void Get5_OnHEGrenadeDetonated(const Get5HEGrenadeEvent event);

// Called when a smoke grenade detonates.
forward void Get5_OnSmokeGrenadeDetonated(const Get5SmokeGrenadeEvent event);

// Called when a molotov grenade expires - or if the round ends (after collecting victim info).
forward void Get5_OnMolotovEnded(const Get5MolotovEvent event);

// Called when the round ends.
forward void Get5_OnRoundEnd(const Get5RoundEndedEvent event);

// Called when the bomb is defused.
forward void Get5_OnBombDefused(const Get5BombDefusedEvent event);

// Called when the bomb is planted.
forward void Get5_OnBombPlanted(const Get5BombPlantedEvent event);

// Called when the bomb explodes.
forward void Get5_OnBombExploded(const Get5BombExplodedEvent event);

// Called when a team selects a side.
forward void Get5_OnSidePicked(const Get5SidePickedEvent event);

// Called when a demo finishes recording.
forward void Get5_OnDemoFinished(const Get5DemoFinishedEvent event);

// Called when a match is paused.
forward void Get5_OnMatchPaused(const Get5MatchPausedEvent event);

// Called when a match is unpaused.
forward void Get5_OnMatchUnpaused(const Get5MatchUnpausedEvent event);

// Called when a match backup is restored.
// Note that the match ID and map number is the one being restored *to*, not the current game state and the time the backup is loaded.
forward void Get5_OnBackupRestore(const Get5BackupRestoredEvent event);

// Returns the current pug gamestate.
native Get5State Get5_GetGameState();

// Prints a plugin-formatted message to a client.
native void Get5_Message(int client, const char[] format, any:...);

// Prints a plugin-formatted message to a team.
native void Get5_MessageToTeam(MatchTeam team, const char[] format, any:...);

// Prints a plugin-formatted message to all clients.
native void Get5_MessageToAll(const char[] format, any:...);

// Loads a match config (keyvalues or JSON) from a local file.
// Returns true if the config was successfully loaded.
native bool Get5_LoadMatchConfig(const char[] filename);

// Loads a match config by downloading a remote config via a HTTP GET request.
// Request parameters should be left out of the url and put into the optional ArrayLists parameters.
native bool Get5_LoadMatchConfigFromURL(const char[] url, ArrayList paramNames = null,
                                        ArrayList paramValues = null);

// Adds a player to a match team. You can optionally force set a player name here as well.
// Returns if they were successfully added.
native bool Get5_AddPlayerToTeam(const char[] steamId, MatchTeam team,
                                 const char[] playerName = "");

// Force sets a steam64 to map to a specified playername
native bool Get5_SetPlayerName(const char[] steamId, const char[] playerName);

// Removes a player from all match teams.
// Returns if they were successfully removed (false if not round).
native bool Get5_RemovePlayerFromTeam(const char[] steamId);

// Returns the current match team a auth is mapped to.
native MatchTeam Get5_GetPlayerTeam(const char[] steamId);

// Translates a CS team (CS_TEAM_T, etc.) to a Match team.
native MatchTeam Get5_CSTeamToMatchTeam(int csTeam);

// Translate da MatchTeam to a CS team.
native int Get5_MatchTeamToCSTeam(MatchTeam team);

// Gets the scores for a match team.
native void Get5_GetTeamScores(MatchTeam team, int& seriesScore, int& currentMapScore);

// Gets the current matchid.
native void Get5_GetMatchID(char[] id, int length);

// Sets the current matchid.
native void Get5_SetMatchID(const char[] id);

// Returns the server ID as defined by get5_server_id.
native int Get5_GetServerID();

// Returns the current map number, 0 being the first in the series.
native int Get5_GetMapNumber();

// Adds a cvar to be set when going live. If the cvar is already in the cvars for the match, the new
// value will replace the old value if the override parameter is true.
// Note: this should only be used when a match config loaded.
native void Get5_AddLiveCvar(const char[] name, const char[] value, bool override = true);

// Copies the current series stats into the passed KeyValues structure.
// Below are the keys used for stats in the kv copied.
// The caller is responsible for creating and deleting a KeyValues
// object if using this method.
native bool Get5_GetMatchStats(KeyValues kv);

// Increases an (integer-typed) player statistic in the plugin's stats keyvalue structure.
native int Get5_IncreasePlayerStat(int client, const char[] statName, int amount = 1);

// Series stats (root section)
#define STAT_SERIESWINNER "winner"
#define STAT_SERIESTYPE "series_type"
#define STAT_SERIES_TEAM1NAME "team1_name"
#define STAT_SERIES_TEAM2NAME "team2_name"
#define STAT_SERIES_FORFEIT "forfeit"

// Map stats (under "map0", "map1", etc.)
#define STAT_MAPNAME "mapname"
#define STAT_MAPWINNER "winner"
#define STAT_DEMOFILENAME "demo_filename"

// Team stats (under map section, then "team1" or "team2")
#define STAT_TEAMSCORE "score"

// Player stats (under map section, then team section, then player's steam64)
#define STAT_NAME "name"
#define STAT_KILLS "kills"
#define STAT_DEATHS "deaths"
#define STAT_ASSISTS "assists"
#define STAT_FLASHBANG_ASSISTS "flashbang_assists"
#define STAT_TEAMKILLS "teamkills"
#define STAT_SUICIDES "suicides"
#define STAT_DAMAGE "damage"
#define STAT_UTILITY_DAMAGE "util_damage"
#define STAT_ENEMIES_FLASHED "enemies_flashed"
#define STAT_FRIENDLIES_FLASHED "friendlies_flashed"
#define STAT_KNIFE_KILLS "knife_kills"
#define STAT_HEADSHOT_KILLS "headshot_kills"
#define STAT_ROUNDSPLAYED "roundsplayed"
#define STAT_BOMBDEFUSES "bomb_defuses"
#define STAT_BOMBPLANTS "bomb_plants"
#define STAT_1K "1kill_rounds"
#define STAT_2K "2kill_rounds"
#define STAT_3K "3kill_rounds"
#define STAT_4K "4kill_rounds"
#define STAT_5K "5kill_rounds"
#define STAT_V1 "v1"
#define STAT_V2 "v2"
#define STAT_V3 "v3"
#define STAT_V4 "v4"
#define STAT_V5 "v5"
#define STAT_FIRSTKILL_T "firstkill_t"
#define STAT_FIRSTKILL_CT "firstkill_ct"
#define STAT_FIRSTDEATH_T "firstdeath_t"
#define STAT_FIRSTDEATH_CT "firstdeath_ct"
#define STAT_TRADEKILL "tradekill"
#define STAT_KAST "kast"
#define STAT_CONTRIBUTION_SCORE "contribution_score"
#define STAT_MVP "mvp"

public SharedPlugin __pl_get5 = {
    name = "get5",
    file = "get5.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_get5_SetNTVOptional() {
  MarkNativeAsOptional("Get5_GetGameState");
  MarkNativeAsOptional("Get5_Message");
  MarkNativeAsOptional("Get5_MessageToTeam");
  MarkNativeAsOptional("Get5_MessageToAll");
  MarkNativeAsOptional("Get5_LoadMatchConfig");
  MarkNativeAsOptional("Get5_LoadMatchConfigFromURL");
  MarkNativeAsOptional("Get5_AddPlayerToTeam");
  MarkNativeAsOptional("Get5_SetPlayerName");
  MarkNativeAsOptional("Get5_RemovePlayerFromTeam");
  MarkNativeAsOptional("Get5_GetPlayerTeam");
  MarkNativeAsOptional("Get5_CSTeamToMatchTeam");
  MarkNativeAsOptional("Get5_MatchTeamToCSTeam");
  MarkNativeAsOptional("Get5_GetTeamScores");
  MarkNativeAsOptional("Get5_GetMatchID");
  MarkNativeAsOptional("Get5_SetMatchID");
  MarkNativeAsOptional("Get5_GetServerID");
  MarkNativeAsOptional("Get5_AddLiveCvar");
  MarkNativeAsOptional("Get5_IncreasePlayerStat");
  MarkNativeAsOptional("Get5_GetMatchStats");
  MarkNativeAsOptinoal("Get5_GetMapNumber");
}
#endif
