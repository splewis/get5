#define GET5_HEADER_MATCHID     "Get5-MatchId"
#define GET5_HEADER_MAPNUMBER   "Get5-MapNumber"
#define GET5_HEADER_ROUNDNUMBER "Get5-RoundNumber"
#define GET5_HEADER_SERVERID    "Get5-ServerId"
#define GET5_HEADER_FILENAME    "Get5-FileName"
#define GET5_HEADER_VERSION     "Get5-Version"

Handle CreateGet5HTTPRequest(const EHTTPMethod method, const char[] url, char[] error) {
  static char formattedUrl[1024];
  strcopy(formattedUrl, 1024, url);
  PrependProtocolToURLIfRequired(formattedUrl, sizeof(formattedUrl));
  Handle request = SteamWorks_CreateHTTPRequest(method, formattedUrl);
  if (request == INVALID_HANDLE) {
    FormatEx(error, PLATFORM_MAX_PATH, "Failed to create HTTP request for URL: %s", formattedUrl);
    return INVALID_HANDLE;
  }
  if (!SetGet5ServerIdHeader(request, error)) {
    delete request;
    return INVALID_HANDLE;
  }
  SetGet5UserAgent(request);
  return request;
}

static void PrependProtocolToURLIfRequired(char[] url, const int urlSize) {
  if (StrContains(url, "http", false) != 0) {
    Format(url, urlSize, "http://%s", url);
  }
}

bool CheckForSuccessfulResponse(const Handle request, const EHTTPStatusCode statusCode) {
  int status = view_as<int>(statusCode);
  if (status < 200 || status >= 300) {
    int responseSize;
    SteamWorks_GetHTTPResponseBodySize(request, responseSize);
    char[] response = new char[responseSize];
    if (SteamWorks_GetHTTPResponseBodyData(request, response, responseSize)) {
      LogDebug("HTTP response body: %s", response);
    } else {
      LogDebug("Failed to read HTTP response body.");
    }
    return false;
  }
  return true;
}

static bool SetGet5UserAgent(const Handle request) {
  static char userAgent[128];
  static bool didWriteBuffer;
  if (!didWriteBuffer) {
    // Since this never changes during the lifetime of the plugin, we only need to write it once.
    FormatEx(userAgent, 128, "SourceMod Get5 %s+https://%s", PLUGIN_VERSION, GET5_GITHUB_PAGE);
    didWriteBuffer = true;
  }
  return SteamWorks_SetHTTPRequestUserAgentInfo(request, userAgent) &&
         SteamWorks_SetHTTPRequestHeaderValue(request, GET5_HEADER_VERSION, PLUGIN_VERSION);
}

bool SetHeaderKeyValuePair(const Handle request, const char[] header, const char[] value, char[] error) {
  if (!SteamWorks_SetHTTPRequestHeaderValue(request, header, value)) {
    FormatEx(error, PLATFORM_MAX_PATH, "Failed to add header '%s' with value '%s' to HTTP request.", header, value);
    return false;
  }
  return true;
}

static bool SetHeaderKeyValuePairInt(const Handle request, const char[] header, const int value, char[] error) {
  char strValue[5];
  IntToString(value, strValue, sizeof(strValue));
  return SetHeaderKeyValuePair(request, header, strValue, error);
}

static bool SetGet5ServerIdHeader(const Handle request, char[] error) {
  char serverId[65];
  g_ServerIdCvar.GetString(serverId, sizeof(serverId));
  if (strlen(serverId) == 0) {
    return true;
  }
  return SetHeaderKeyValuePair(request, GET5_HEADER_SERVERID, serverId, error);
}

bool AddFileAsHttpBody(const Handle request, const char[] file, char[] error) {
  if (!FileExists(file) || !SteamWorks_SetHTTPRequestRawPostBodyFromFile(request, "application/octet-stream", file)) {
    FormatEx(error, PLATFORM_MAX_PATH, "Failed to add file '%s' as POST body for HTTP request.", file);
    return false;
  }
  return true;
}

bool SetFileNameHeader(const Handle request, const char[] filename, char[] error) {
  return SetHeaderKeyValuePair(request, GET5_HEADER_FILENAME, filename, error);
}

bool SetMatchIdHeader(const Handle request, const char[] matchId, char[] error) {
  if (strlen(matchId) == 0) {
    return true;
  }
  return SetHeaderKeyValuePair(request, GET5_HEADER_MATCHID, matchId, error);
}

bool SetMapNumberHeader(const Handle request, const int mapNumber, char[] error) {
  return SetHeaderKeyValuePairInt(request, GET5_HEADER_MAPNUMBER, mapNumber, error);
}

bool SetRoundNumberHeader(const Handle request, const int roundNumber, char[] error) {
  return SetHeaderKeyValuePairInt(request, GET5_HEADER_ROUNDNUMBER, roundNumber, error);
}

bool SetMultipleHeaders(const Handle request, const ArrayList headerNames, const ArrayList headerValues, char[] error) {
  char key[1024];
  char value[1024];
  if (headerNames == null && headerValues == null) {
    return true;
  }
  if (headerNames.Length != headerValues.Length) {
    FormatEx(error, PLATFORM_MAX_PATH, "The number of header keys and values must be identical.");
    return false;
  }
  for (int i = 0; i < headerNames.Length; i++) {
    headerNames.GetString(i, key, sizeof(key));
    headerValues.GetString(i, value, sizeof(value));
    if (!SetHeaderKeyValuePair(request, key, value, error)) {
      return false;
    }
  }
  return true;
}

bool SetMultipleQueryParameters(const Handle request, const ArrayList paramNames, const ArrayList paramValues,
                                char[] error) {
  char key[1024];
  char value[1024];
  if (paramNames == null && paramValues == null) {
    return true;
  }
  if (paramNames.Length != paramValues.Length) {
    FormatEx(error, PLATFORM_MAX_PATH, "The number of query parameter keys and values must be identical.");
    return false;
  }
  for (int i = 0; i < paramNames.Length; i++) {
    paramNames.GetString(i, key, sizeof(key));
    paramValues.GetString(i, value, sizeof(value));
    if (!SteamWorks_SetHTTPRequestGetOrPostParameter(request, key, value)) {
      FormatEx(error, PLATFORM_MAX_PATH, "Failed to set HTTP query parameter '%s' with value '%s'.", key, value);
      return false;
    }
  }
  return true;
}
