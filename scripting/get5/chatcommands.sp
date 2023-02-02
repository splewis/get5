void AddAliasedCommand(const char[] command, ConCmd callback, const char[] description) {
  char smCommandBuffer[COMMAND_LENGTH];
  FormatEx(smCommandBuffer, sizeof(smCommandBuffer), "sm_%s", command);
  RegConsoleCmd(smCommandBuffer, callback, description);

  char dotCommandBuffer[ALIAS_LENGTH];
  FormatEx(dotCommandBuffer, sizeof(dotCommandBuffer), ".%s", command);
  AddChatAlias(dotCommandBuffer, smCommandBuffer);
}

static void AddChatAlias(const char[] alias, const char[] command) {
  // Don't allow duplicate aliases to be added.
  if (g_ChatAliases.FindString(alias) == -1) {
    g_ChatAliases.PushString(alias);
    g_ChatAliasesCommands.PushString(command);
  }
}

void MapChatCommand(const Get5ChatCommand command, const char[] alias) {
  switch (command) {
    case Get5ChatCommand_Ready: {
      AddAliasedCommand(alias, Command_Ready, "Marks the client as ready.");
    }
    case Get5ChatCommand_Unready: {
      AddAliasedCommand(alias, Command_NotReady, "Marks the client as not ready.");
    }
    case Get5ChatCommand_ForceReady: {
      AddAliasedCommand(alias, Command_ForceReadyClient, "Marks the client's entire team as ready.");
    }
    case Get5ChatCommand_Tech: {
      AddAliasedCommand(alias, Command_TechPause, "Calls for a technical pause.");
    }
    case Get5ChatCommand_Pause: {
      AddAliasedCommand(alias, Command_Pause, "Calls for a tactical pause.");
    }
    case Get5ChatCommand_Unpause: {
      AddAliasedCommand(alias, Command_Unpause, "Unpauses the game.");
    }
    case Get5ChatCommand_Coach: {
      AddAliasedCommand(alias, Command_SmCoach, "Requests to become a coach.");
    }
    case Get5ChatCommand_Stay: {
      AddAliasedCommand(alias, Command_Stay, "Elects to stay on the current side after winning a knife round.");
    }
    case Get5ChatCommand_Swap: {
      AddAliasedCommand(alias, Command_Swap, "Elects to swap to the other side after winning a knife round.");
    }
    case Get5ChatCommand_T: {
      AddAliasedCommand(alias, Command_T, "Elects to start on T side after winning a knife round.");
    }
    case Get5ChatCommand_CT: {
      AddAliasedCommand(alias, Command_Ct, "Elects to start on CT side after winning a knife round.");
    }
    case Get5ChatCommand_Stop: {
      AddAliasedCommand(alias, Command_Stop, "Elects to stop the game to reload a backup file for the current round.");
    }
    case Get5ChatCommand_Surrender: {
      AddAliasedCommand(alias, Command_Surrender, "Starts a vote for surrendering for your team.");
    }
    case Get5ChatCommand_FFW: {
      AddAliasedCommand(alias, Command_FFW, "Starts a countdown to win if a full team disconnects from the server.");
    }
    case Get5ChatCommand_CancelFFW: {
      AddAliasedCommand(alias, Command_CancelFFW, "Cancels a pending request to win by forfeit.");
    }
    case Get5ChatCommand_Pick: {
      AddAliasedCommand(alias, Command_Pick, "Picks a map to play from the map pool.");
    }
    case Get5ChatCommand_Ban: {
      AddAliasedCommand(alias, Command_Ban, "Bans a map from the map pool.");
    }
    default: {
      LogError("Failed to map Get5ChatCommand with value %d to a command. It is missing from MapChatCommand.", command);
      return;
    }
  }

  char commandAsString[64];        // "ready"; base command
  char commandAliasFormatted[64];  // "!readyalias"; the alias to use, with ! in front
  ChatCommandToString(command, commandAsString, sizeof(commandAsString));
  FormatEx(commandAliasFormatted, sizeof(commandAliasFormatted), "!%s", alias);
  g_ChatCommands.SetString(commandAsString, commandAliasFormatted);  // maps ready -> !readyalias
}

void GetChatAliasForCommand(const Get5ChatCommand command, char[] buffer, int bufferSize, bool format) {
  char commandAsString[64];
  ChatCommandToString(command, commandAsString, sizeof(commandAsString));
  g_ChatCommands.GetString(commandAsString, buffer, bufferSize);
  if (format) {
    FormatChatCommand(buffer, bufferSize, buffer);
  }
}

int LoadCustomChatAliases(const char[] file) {
  int loadedAliases = 0;
  if (!FileExists(file)) {
    LogDebug("Custom chat commands file not found at '%s'. Skipping.", file);
    return loadedAliases;
  }
  char error[PLATFORM_MAX_PATH];
  if (!CheckKeyValuesFile(file, error, sizeof(error))) {
    LogError("Failed to parse custom chat command file. Error: %s", error);
    return loadedAliases;
  }

  KeyValues chatAliases = new KeyValues("Commands");
  if (!chatAliases.ImportFromFile(file)) {
    LogError("Failed to read chat command aliases file at '%s'.", file);
    delete chatAliases;
    return loadedAliases;
  }

  if (chatAliases.GotoFirstSubKey(false)) {
    char alias[255];
    char command[255];
    do {
      chatAliases.GetSectionName(alias, sizeof(alias));
      chatAliases.GetString(NULL_STRING, command, sizeof(command));

      Get5ChatCommand chatCommand = StringToChatCommand(command);
      if (chatCommand == Get5ChatCommand_Unknown) {
        LogError("Failed to alias unknown chat command '%s' to '%s'.", command, alias);
        continue;
      }
      MapChatCommand(chatCommand, alias);
      loadedAliases++;
    } while (chatAliases.GotoNextKey(false));
    if (loadedAliases > 0) {
      LogMessage("Loaded %d custom chat alias(es).", loadedAliases);
    }
  } else {
    // file is empty.
    LogDebug("Custom alias file was empty.");
  }
  delete chatAliases;
  return loadedAliases;
}

void CheckForChatAlias(int client, const char[] sArgs) {
  // No chat aliases are needed if the game isn't setup at all.
  if (g_GameState == Get5State_None) {
    return;
  }

  // Splits to find the first word to do a chat alias command check.
  char chatCommand[COMMAND_LENGTH];
  char chatArgs[255];
  int index = SplitString(sArgs, " ", chatCommand, sizeof(chatCommand));

  if (index == -1) {
    strcopy(chatCommand, sizeof(chatCommand), sArgs);
  } else if (index < strlen(sArgs)) {
    strcopy(chatArgs, sizeof(chatArgs), sArgs[index]);
  }

  if (chatCommand[0] && IsPlayer(client)) {
    char alias[ALIAS_LENGTH];
    char cmd[COMMAND_LENGTH];
    for (int i = 0; i < GetArraySize(g_ChatAliases); i++) {
      GetArrayString(g_ChatAliases, i, alias, sizeof(alias));
      GetArrayString(g_ChatAliasesCommands, i, cmd, sizeof(cmd));
      if (CheckChatAlias(alias, cmd, chatCommand, chatArgs, client)) {
        break;
      }
    }
  }
}

static bool CheckChatAlias(const char[] alias, const char[] command, const char[] chatCommand, const char[] chatArgs,
                           int client) {
  if (StrEqual(chatCommand, alias, false)) {
    // Get the original cmd reply source so it can be restored after the fake client command.
    // This means and ReplyToCommand will go into the chat area, rather than console, since
    // *chat* aliases are for *chat* commands.
    ReplySource replySource = GetCmdReplySource();
    SetCmdReplySource(SM_REPLY_TO_CHAT);
    char fakeCommand[256];
    FormatEx(fakeCommand, sizeof(fakeCommand), "%s %s", command, chatArgs);
    FakeClientCommand(client, fakeCommand);
    SetCmdReplySource(replySource);
    return true;
  }
  return false;
}
