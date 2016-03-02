public Action Command_JoinGame(int client, const char[] command, int argc) {
    if (g_GameState == GameState_None) {
        return Plugin_Continue;
    }

    // TODO: if we want to bypass the teammenu, this is probably the best
    // place to put the player onto a team.
    // if (IsPlayer(client)) {
    //     FakeClientCommand(client, "jointeam 2");
    // }

    return Plugin_Continue;
}

// public void CheckClientTeam(int client) {
//     MatchTeam correctTeam = GetClientMatchTeam(client);
//     int csTeam = MatchTeamToCSTeam(correctTeam);
//     int currentTeam = GetClientTeam(client);

//     if (csTeam != currentTeam) {
//         if (IsClientCoaching(client)) {
//             UpdateCoachTarget(client, csTeam);
//         }

//         LogDebug("CheckClientTeam %L to %d", client, csTeam);
//         SwitchPlayerTeam(client, csTeam);
//     }
// }

public Action Command_JoinTeam(int client, const char[] command, int argc) {
    if (!IsAuthedPlayer(client) || argc < 1)
        return Plugin_Stop;

    // Don't do anything if not live/not in startup phase.
    if (g_GameState == GameState_None) {
        return Plugin_Continue;
    }

    char arg[4];
    GetCmdArg(1, arg, sizeof(arg));
    int team_to = StringToInt(arg);

    LogDebug("%L jointeam command, from %d to %d", client, GetClientTeam(client), team_to);

    // don't let someone change to a "none" team (e.g. using auto-select)
    if (team_to == CS_TEAM_NONE) {
        return Plugin_Stop;
    }

    MatchTeam correctTeam = GetClientMatchTeam(client);
    int csTeam = MatchTeamToCSTeam(correctTeam);

    LogDebug("jointeam, gamephase = %d", GetGamePhase());

    if (g_PendingSideSwap) {
        LogDebug("Blocking teamjoin due to pending swap");
        // SwitchPlayerTeam(client, csTeam);
        return Plugin_Handled;
    }

    if (csTeam == team_to) {
        return Plugin_Continue;
    }

    if (csTeam != GetClientTeam(client)) {
        // SwitchPlayerTeam(client, csTeam);
        int count = CountPlayersOnCSTeam(csTeam);

        if (count >= g_PlayersPerTeam) {
            if (g_CoachingEnabledCvar.IntValue == 0) {
                KickClient(client, "Your team is full");
            } else {
                LogDebug("Forcing player %N to coach", client);
                MoveClientToCoach(client);
                Get5_Message(client, "Because your team is full, you were moved to the coach position.");
            }
        } else {
            LogDebug("Forcing player %N onto %d", client, csTeam);
            FakeClientCommand(client, "jointeam %d", csTeam);
        }

        return Plugin_Stop;
    }

    return Plugin_Stop;
}

public void MoveClientToCoach(int client) {
    LogDebug("MoveClientToCoach %L", client);
    MatchTeam matchTeam = GetClientMatchTeam(client);
    if (matchTeam != MatchTeam_Team1 && matchTeam != MatchTeam_Team2) {
        return;
    }

    if (g_CoachingEnabledCvar.IntValue == 0) {
        return;
    }

    int csTeam = MatchTeamToCSTeam(matchTeam);

    if (g_PendingSideSwap) {
        LogDebug("Blocking coach move due to pending swap");
        // SwitchPlayerTeam(client, CS_TEAM_SPECTATOR);
        // UpdateCoachTarget( client, csTeam);
        return;
    }

    char teamString[4];
    CSTeamString(csTeam, teamString, sizeof(teamString));

    // If we're in warmup or a freezetime we use the in-game
    // coaching command. Otherwise we manually move them to spec
    // and set the coaching target.
    if (!InWarmup() && !InFreezeTime()) {
        // TODO: this needs to be tested more thoroughly,
        // it might need to be done in reverse order (?)
        SwitchPlayerTeam(client, CS_TEAM_SPECTATOR);
        UpdateCoachTarget(client, csTeam);
    } else {
        g_MovingClientToCoach[client] = true;
        FakeClientCommand(client, "coach %s", teamString);
        g_MovingClientToCoach[client] = false;
    }
}

public Action Command_SmCoach(int client, int args) {
    if (g_CoachingEnabledCvar.IntValue == 0) {
        return Plugin_Handled;
    }

    MoveClientToCoach(client);
    return Plugin_Handled;
}

public Action Command_Coach(int client, const char[] command, int argc) {
    if (g_CoachingEnabledCvar.IntValue == 0) {
        return Plugin_Handled;
    }

    if (!IsAuthedPlayer(client)) {
        return Plugin_Stop;
    }

    if (InHalftimePhase()) {
        return Plugin_Stop;
    }

    if (g_MovingClientToCoach[client]) {
        return Plugin_Continue;
    }

    MoveClientToCoach(client);
    return Plugin_Stop;
}

public MatchTeam GetClientMatchTeam(int client) {
    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AUTH_METHOD, auth, sizeof(auth));
    return GetAuthMatchTeam(auth);
}

public int MatchTeamToCSTeam(MatchTeam t) {
    if (t == MatchTeam_Team1) {
        return g_TeamSide[MatchTeam_Team1];
    } else if (t == MatchTeam_Team2) {
        return g_TeamSide[MatchTeam_Team2];
    } else if (t == MatchTeam_TeamSpec) {
        return CS_TEAM_SPECTATOR;
    } else {
        return CS_TEAM_NONE;
    }
}

public MatchTeam CSTeamToMatchTeam(int csTeam) {
    if (csTeam == g_TeamSide[MatchTeam_Team1]) {
        return MatchTeam_Team1;
    } else if (csTeam == g_TeamSide[MatchTeam_Team2]) {
        return MatchTeam_Team2;
    } else if (csTeam == CS_TEAM_SPECTATOR) {
        return MatchTeam_TeamSpec;
    } else {
        return MatchTeam_TeamNone;
    }
}

public MatchTeam GetAuthMatchTeam(const char[] auth) {
    for (int i = 0; i < view_as<int>(MatchTeam_Count); i++) {
        MatchTeam team = view_as<MatchTeam>(i);
        if (IsAuthOnTeam(auth, team)) {
            return team;
        }
    }
    return MatchTeam_TeamNone;
}

stock int CountPlayersOnCSTeam(int team, int exclude=-1) {
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (i != exclude && IsAuthedPlayer(i) && GetClientTeam(i) == team) {
            count++;
        }
    }
    return count;
}

stock int CountPlayersOnMatchTeam(MatchTeam team, int exclude=-1) {
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (i != exclude && IsAuthedPlayer(i) && GetClientMatchTeam(i) == team) {
            count++;
        }
    }
    return count;
}

public Action Event_OnPlayerTeam(Event event, const char[] name, bool dontBroadcast) {
    return Plugin_Continue;
}

// Returns the match team a client is the captain of, or MatchTeam_None.
public MatchTeam GetCaptainTeam(int client) {
    if (client == GetTeamCaptain(MatchTeam_Team1)) {
        return MatchTeam_Team1;
    } else if (client == GetTeamCaptain(MatchTeam_Team2)) {
        return MatchTeam_Team2;
    } else {
        return MatchTeam_TeamNone;
    }
}

public int GetTeamCaptain(MatchTeam team) {
    ArrayList auths = GetTeamAuths(team);
    char buffer[AUTH_LENGTH];
    for (int i = 0; i < auths.Length; i++) {
        auths.GetString(i, buffer, sizeof(buffer));
        int client = AuthToClient(buffer);
        if (IsAuthedPlayer(client)) {
            return client;
        }
    }
    return -1;
}

public int GetNextTeamCaptain(int client) {
    if (client == g_VetoCaptains[MatchTeam_Team1]) {
        return g_VetoCaptains[MatchTeam_Team2];
    } else {
        return g_VetoCaptains[MatchTeam_Team1];
    }
}

public ArrayList GetTeamAuths(MatchTeam team) {
    return g_TeamAuths[team];
}

public bool IsAuthOnTeam(const char[] auth, MatchTeam team) {
    return IsAuthInList(auth, GetTeamAuths(team));
}

public bool IsAuthInList(const char[] auth, ArrayList list) {
    char buffer[AUTH_LENGTH];
    for (int i = 0; i < list.Length; i++) {
        list.GetString(i, buffer, sizeof(buffer));
        if (SteamIdsEqual(auth, buffer)) {
            return true;
        }
    }
    return false;
}

public void SetStartingTeams() {
    int mapNumber = GetMapNumber();
    if (mapNumber >= g_MapSides.Length || g_MapSides.Get(mapNumber) == SideChoice_KnifeRound) {
        g_TeamSide[MatchTeam_Team1] = TEAM1_STARTING_SIDE;
        g_TeamSide[MatchTeam_Team2] = TEAM2_STARTING_SIDE;
    } else {
        if (g_MapSides.Get(mapNumber) == SideChoice_Team1CT) {
            g_TeamSide[MatchTeam_Team1] = CS_TEAM_CT;
            g_TeamSide[MatchTeam_Team2] = CS_TEAM_T;
        }  else {
            g_TeamSide[MatchTeam_Team1] = CS_TEAM_T;
            g_TeamSide[MatchTeam_Team2] = CS_TEAM_CT;
        }
    }
}

public void AddMapScore() {
    int currentMapNumber = GetMapNumber();

    g_TeamScoresPerMap.Push(0);
    g_TeamScoresPerMap.Set(
        currentMapNumber,
        CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)),
        view_as<int>(MatchTeam_Team1));

    g_TeamScoresPerMap.Set(
        currentMapNumber,
        CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)),
        view_as<int>(MatchTeam_Team2));
}

public int GetMapScore(int mapNumber, MatchTeam team) {
    return g_TeamScoresPerMap.Get(mapNumber, view_as<int>(team));
}

public int GetMapNumber() {
    return g_TeamSeriesScores[MatchTeam_Team1] + g_TeamSeriesScores[MatchTeam_Team2];
}

public bool AddPlayerToTeam(const char[] auth, MatchTeam team) {
    if (GetAuthMatchTeam(auth) == MatchTeam_TeamNone) {
        GetTeamAuths(team).PushString(auth);
        return true;
    } else {
        return false;
    }
}

public bool RemovePlayerFromTeams(const char[] auth) {
    for (int i = 0; i < view_as<int>(MatchTeam_Count); i++) {
        MatchTeam team = view_as<MatchTeam>(i);
        if (RemoveAuthFromArray(GetTeamAuths(team), auth)) {
            int target = AuthToClient(auth);
            if (IsAuthedPlayer(target)) {
                KickClient(target, "You are not a player in this match");
            }
            return true;
        }
    }
    return false;
}
