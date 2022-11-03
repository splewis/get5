void SendEventJSONToURL(const char[] event) {
  const eventUrlSize = 1024;
  static char eventUrl[eventUrlSize];
  g_EventLogRemoteURLCvar.GetString(eventUrl, eventUrlSize);
  if (strlen(eventUrl) == 0) {
    return;
  }

  if (!LibraryExists("SteamWorks")) {
    char cVarName[MAX_CVAR_LENGTH];
    g_EventLogRemoteURLCvar.GetName(cVarName, sizeof(cVarName));
    LogError("Cannot send HTTP events without the SteamWorks extension. Disabling %s.", cVarName);
    g_EventLogRemoteURLCvar.SetString("");
    return;
  }

  Handle eventRequest = CreateGet5HTTPRequest(k_EHTTPMethodPOST, eventUrl);
  if (eventRequest == INVALID_HANDLE) {
    return;
  }

  static char eventUrlHeaderKey[1024];
  static char eventUrlHeaderValue[1024];

  g_EventLogRemoteHeaderKeyCvar.GetString(eventUrlHeaderKey, sizeof(eventUrlHeaderKey));
  g_EventLogRemoteHeaderValueCvar.GetString(eventUrlHeaderValue, sizeof(eventUrlHeaderValue));

  if (strlen(eventUrlHeaderKey) > 0 && strlen(eventUrlHeaderValue) > 0) {
    if (!SteamWorks_SetHTTPRequestHeaderValue(eventRequest, eventUrlHeaderKey, eventUrlHeaderValue)) {
      LogError("Failed to add header '%s' with value '%s' to event HTTP request.", eventUrlHeaderKey,
               eventUrlHeaderValue);
      delete eventRequest;
      return;
    }
  }
  SteamWorks_SetHTTPRequestRawPostBody(eventRequest, "application/json", event, strlen(event));
  SteamWorks_SetHTTPRequestNetworkActivityTimeout(eventRequest, 15);  // Default 60 is a bit much.
  SteamWorks_SetHTTPCallbacks(eventRequest, EventRequestCallback);
  SteamWorks_SendHTTPRequest(eventRequest);
}

static int EventRequestCallback(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode) {
  if (failure || !requestSuccessful) {
    LogError("Event HTTP request failed due to a network or configuration error.");
    delete request;
    return;
  }
  int status = view_as<int>(statusCode);
  if (status >= 300 || status < 200) {
    LogError("Event HTTP request failed with status code: %d.", statusCode);
    int responseSize;
    SteamWorks_GetHTTPResponseBodySize(request, responseSize);
    char[] response = new char[responseSize];
    if (SteamWorks_GetHTTPResponseBodyData(request, response, responseSize)) {
      LogError("Response body: %s", response);
    } else {
      LogError("Failed to read response body.");
    }
  }
  delete request;
}
