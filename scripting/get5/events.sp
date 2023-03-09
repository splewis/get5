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

  int contentLength = strlen(event);
  if (contentLength >= 16383) {
    LogError(
      "JSON event size exceeds the maximum supported value of 16382 bytes and cannot be sent to your log URL. You should consider setting get5_pretty_print_json 0 to reduce the JSON size.");
    return;
  }

  static char error[PLATFORM_MAX_PATH];
  Handle eventRequest = CreateGet5HTTPRequest(k_EHTTPMethodPOST, eventUrl, error);
  if (eventRequest == INVALID_HANDLE) {
    LogError(error);
    return;
  }

  static char eventUrlHeaderKey[1024];
  static char eventUrlHeaderValue[1024];

  g_EventLogRemoteHeaderKeyCvar.GetString(eventUrlHeaderKey, sizeof(eventUrlHeaderKey));
  g_EventLogRemoteHeaderValueCvar.GetString(eventUrlHeaderValue, sizeof(eventUrlHeaderValue));

  if (strlen(eventUrlHeaderKey) > 0 && strlen(eventUrlHeaderValue) > 0 &&
      !SetHeaderKeyValuePair(eventRequest, eventUrlHeaderKey, eventUrlHeaderValue, error)) {
    LogError(error);
    delete eventRequest;
    return;
  }

  SteamWorks_SetHTTPRequestRawPostBody(eventRequest, "application/json", event, contentLength);
  SteamWorks_SetHTTPRequestNetworkActivityTimeout(eventRequest, 15);  // Default 60 is a bit much.
  SteamWorks_SetHTTPCallbacks(eventRequest, EventRequestCallback);
  SteamWorks_SendHTTPRequest(eventRequest);
}

static void EventRequestCallback(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode) {
  if (failure || !requestSuccessful) {
    LogError(
      "Event HTTP request failed due to a network or configuration error. Make sure you have enclosed your event URL in quotes.");
  } else if (!CheckForSuccessfulResponse(request, statusCode)) {
    LogError("Event HTTP request failed with status code: %d.", statusCode);
  }
  delete request;
}
