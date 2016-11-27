public void AddAliasedCommand(const char[] command, ConCmd callback, const char[] description) {
  char smCommandBuffer[COMMAND_LENGTH];
  Format(smCommandBuffer, sizeof(smCommandBuffer), "sm_%s", command);
  RegConsoleCmd(smCommandBuffer, callback, description);

  char dotCommandBuffer[ALIAS_LENGTH];
  Format(dotCommandBuffer, sizeof(dotCommandBuffer), ".%s", command);
  AddChatAlias(dotCommandBuffer, smCommandBuffer);
}

public void AddChatAlias(const char[] alias, const char[] command) {
  // Don't allow duplicate aliases to be added.
  if (g_ChatAliases.FindString(alias) == -1) {
    g_ChatAliases.PushString(alias);
    g_ChatAliasesCommands.PushString(command);
  }
}

public void CheckForChatAlias(int client, const char[] command, const char[] sArgs) {
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

static bool CheckChatAlias(const char[] alias, const char[] command, const char[] chatCommand,
                           const char[] chatArgs, int client) {
  if (StrEqual(chatCommand, alias, false)) {
    // Get the original cmd reply source so it can be restored after the fake client command.
    // This means and ReplyToCommand will go into the chat area, rather than console, since
    // *chat* aliases are for *chat* commands.
    ReplySource replySource = GetCmdReplySource();
    SetCmdReplySource(SM_REPLY_TO_CHAT);
    char fakeCommand[256];
    Format(fakeCommand, sizeof(fakeCommand), "%s %s", command, chatArgs);
    FakeClientCommand(client, fakeCommand);
    SetCmdReplySource(replySource);
    return true;
  }
  return false;
}
