stock bool json_has_key(Handle hObj, const char[] key, json_type expectedType = JSON_NULL) {
  Handle h = json_object_get(hObj, key);
  if (h == INVALID_HANDLE) {
    return false;
  } else {
    // Perform type-checking.
    json_type actualType = json_typeof(h);
    if (expectedType != JSON_NULL && actualType != expectedType) {
      char expectedTypeStr[16];
      char actualTypeStr[16];
      Stringify_json_type(expectedType, expectedTypeStr, sizeof(expectedTypeStr));
      Stringify_json_type(actualType, actualTypeStr, sizeof(actualTypeStr));
      LogError("Type mismatch for key \"%s\", got %s when expected a %s", key, actualTypeStr,
               expectedTypeStr);
      return false;
    }
    CloseHandle(h);
    return true;
  }
}

stock int json_object_get_string_safe(Handle hObj, const char[] key, char[] buffer, int maxlength,
                                      const char[] defaultValue = "") {
  if (json_has_key(hObj, key, JSON_STRING)) {
    return json_object_get_string(hObj, key, buffer, maxlength);
  } else {
    return strcopy(buffer, maxlength, defaultValue);
  }
}

stock int json_object_get_int_safe(Handle hObj, const char[] key, int defaultValue = 0) {
  if (json_has_key(hObj, key, JSON_INTEGER)) {
    return json_object_get_int(hObj, key);
  } else {
    return defaultValue;
  }
}

stock bool json_object_get_bool_safe(Handle hObj, const char[] key, bool defaultValue = false) {
  if (json_has_key(hObj, key)) {
    return json_object_get_bool(hObj, key);
  } else {
    return defaultValue;
  }
}

stock float json_object_get_float_safe(Handle hObj, const char[] key, float defaultValue = 0.0) {
  if (json_has_key(hObj, key, JSON_REAL)) {
    return json_object_get_float(hObj, key);
  } else {
    return defaultValue;
  }
}

stock int AddJsonSubsectionArrayToList(Handle json, const char[] key, ArrayList list,
                                       int maxValueLength) {
  int count = 0;
  Handle array = json_object_get(json, key);
  if (array != INVALID_HANDLE) {
    char[] buffer = new char[maxValueLength];
    for (int i = 0; i < json_array_size(array); i++) {
      json_array_get_string(array, i, buffer, maxValueLength);
      list.PushString(buffer);
      count++;
    }
    CloseHandle(array);
  }
  return count;
}

stock int AddJsonAuthsToList(Handle json, const char[] key, ArrayList list, int maxValueLength) {
  int count = 0;
  // We handle two formats here: one where we get a array of steamids as strings, and in the
  // 2nd format we have a map of steamid- > player name.
  Handle data = json_object_get(json, key);
  if (data != INVALID_HANDLE) {
    if (json_is_array(data)) {
      char[] buffer = new char[maxValueLength];
      for (int i = 0; i < json_array_size(data); i++) {
        json_array_get_string(data, i, buffer, maxValueLength);
        char steam64[AUTH_LENGTH];
        if (ConvertAuthToSteam64(buffer, steam64)) {
          list.PushString(steam64);
          count++;
        }
      }

    } else if (json_is_object(data)) {
      for (Handle it = json_object_iter(data); it != INVALID_HANDLE;
           it = json_object_iter_next(data, it)) {
        char[] buffer = new char[maxValueLength];
        char name[MAX_NAME_LENGTH];
        json_object_iter_key(it, buffer, maxValueLength);
        json_object_get_string(data, buffer, name, sizeof(name));

        char steam64[AUTH_LENGTH];
        if (ConvertAuthToSteam64(buffer, steam64)) {
          Get5_SetPlayerName(steam64, name);
          list.PushString(steam64);
          count++;
        }
      }
    }
    CloseHandle(data);
  }
  return count;
}

stock void set_json_string(Handle root_json, const char[] key, const char[] value) {
  Handle value_json = json_string(value);
  json_object_set(root_json, key, value_json);
  CloseHandle(value_json);
}

stock void set_json_int(Handle root_json, const char[] key, int value) {
  Handle value_json = json_integer(value);
  json_object_set(root_json, key, value_json);
  CloseHandle(value_json);
}

stock void set_json_bool(Handle root_json, const char[] key, bool value) {
  Handle value_json = json_boolean(value);
  json_object_set(root_json, key, value_json);
  CloseHandle(value_json);
}
