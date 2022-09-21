#define GET5_HEADER_MATCHID "Get5-MatchId"
#define GET5_HEADER_MAPNUMBER "Get5-MapNumber"
#define GET5_HEADER_SERVERID "Get5-ServerId"
#define GET5_HEADER_DEMONAME "Get5-DemoName"

Handle CreateGet5HTTPRequest(const EHTTPMethod method, const char[] url) {
  static char formattedUrl[1024];
  strcopy(formattedUrl, 1024, url);
  PrependProtocolToURLIfRequired(formattedUrl, sizeof(formattedUrl));
  Handle request = SteamWorks_CreateHTTPRequest(method, formattedUrl);
  if (request == INVALID_HANDLE) {
    LogError("Failed to create HTTP request for URL: %s", formattedUrl);
    return INVALID_HANDLE;
  }
  SetGet5ServerIdHeader(request);
  SetGet5UserAgent(request);
  return request;
}

static void PrependProtocolToURLIfRequired(char[] url, const int urlSize) {
  if (StrContains(url, "http", false) != 0) {
    Format(url, urlSize, "http://%s", url);
  }
}

static bool SetGet5UserAgent(const Handle request) {
  static char userAgent[128];
  static bool didWriteBuffer;
  if (!didWriteBuffer) {
    // Since this never changes during the lifetime of the plugin, we only need to format it once.
    FormatEx(userAgent, 128, "SourceMod Get5 %s+https://%s", PLUGIN_VERSION, GET5_GITHUB_PAGE);
    didWriteBuffer = true;
  }
  return SteamWorks_SetHTTPRequestUserAgentInfo(request, userAgent);
}

static bool SetGet5ServerIdHeader(const Handle request) {
  char serverIdString[32];
  int serverId = Get5_GetServerID();
  if (serverId < 1) {
    return true;
  }
  IntToString(serverId, serverIdString, sizeof(serverIdString));
  return SteamWorks_SetHTTPRequestHeaderValue(request, GET5_HEADER_SERVERID, serverIdString);
}
