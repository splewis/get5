#include <string>

stock JSON_Object json_load_file(const char[] path) {
  File f = OpenFile(path, "r");
  char contents[8192];
  f.ReadString(contents, sizeof(contents));
  delete f;
  return json_decode(contents);
}

stock void json_string_type(JSONCellType type, char[] output, int maxlength) {
  switch (type) {
    case JSON_Type_Invalid:
      Format(output, maxlength, "invalid");
    case JSON_Type_String:
      Format(output, maxlength, "string");
    case JSON_Type_Int:
      Format(output, maxlength, "int");
    case JSON_Type_Float:
      Format(output, maxlength, "float");
    case JSON_Type_Bool:
      Format(output, maxlength, "bool");
    case JSON_Type_Object:
      Format(output, maxlength, "object");
  }
}

stock bool json_has_key(JSON_Object json, const char[] key, JSONCellType expectedType) {
  if (json == null) {
    return false;
  } else if (!json.HasKey(key)) {
    return false;
  } else {
    // Perform type-checking.
    JSONCellType actualType = json.GetKeyType(key);
    if (actualType != expectedType) {
      char expectedTypeStr[16];
      char actualTypeStr[16];
      json_string_type(expectedType, expectedTypeStr, sizeof(expectedTypeStr));
      json_string_type(actualType, actualTypeStr, sizeof(actualTypeStr));
      LogError("Type mismatch for key \"%s\", got %s when expected a %s", key, actualTypeStr,
               expectedTypeStr);
      return false;
    }
    return true;
  }
}

stock int json_object_get_string_safe(JSON_Object json, const char[] key, char[] buffer,
                                      int maxlength, const char[] defaultValue = "") {
  if (json_has_key(json, key, JSON_Type_String)) {
    return json.GetString(key, buffer, maxlength);
  } else {
    return strcopy(buffer, maxlength, defaultValue);
  }
}

stock int json_object_get_int_safe(JSON_Object json, const char[] key, int defaultValue = 0) {
  if (json_has_key(json, key, JSON_Type_Int)) {
    return json.GetInt(key);
  } else {
    return defaultValue;
  }
}

stock bool json_object_get_bool_safe(JSON_Object json, const char[] key,
                                     bool defaultValue = false) {
  if (json_has_key(json, key, JSON_Type_Bool)) {
    return json.GetBool(key);
  } else {
    return defaultValue;
  }
}

stock float json_object_get_float_safe(JSON_Object json, const char[] key,
                                       float defaultValue = 0.0) {
  if (json_has_key(json, key, JSON_Type_Float)) {
    return json.GetFloat(key);
  } else {
    return defaultValue;
  }
}

// Used for parsing an Array[String] to a sourcepawn ArrayList of strings
stock int AddJsonSubsectionArrayToList(JSON_Object json, const char[] key, ArrayList list,
                                       int maxValueLength) {
  if (!json_has_key(json, key, JSON_Type_Object)) {
    return 0;
  }

  int count = 0;
  JSON_Array array = view_as<JSON_Array>(json.GetObject(key));
  if (array != null) {
    char[] buffer = new char[maxValueLength];
    for (int i = 0; i < array.Length; i++) {
      array.GetString(i, buffer, maxValueLength);
      list.PushString(buffer);
      count++;
    }
    array.Cleanup();
  }
  return count;
}

// Used for mapping a keyvalue section
stock int AddJsonAuthsToList(JSON_Object json, const char[] key, ArrayList list,
                             int maxValueLength) {
  int count = 0;
  // We handle two formats here: one where we get a array of steamids as strings, and in the
  // 2nd format we have a map of steamid- > player name.
  JSON_Object data = json.GetObject(key);
  if (data != null) {
    if (data.IsArray) {
      JSON_Array array = view_as<JSON_Array>(data);
      char[] buffer = new char[maxValueLength];
      for (int i = 0; i < array.Length; i++) {
        array.GetString(i, buffer, maxValueLength);
        char steam64[AUTH_LENGTH];
        if (ConvertAuthToSteam64(buffer, steam64)) {
          list.PushString(steam64);
          count++;
        }
      }

    } else {
      StringMapSnapshot snap = data.Snapshot();
      char[] buffer = new char[maxValueLength];
      char name[MAX_NAME_LENGTH];
      for (int i = 0; i < snap.Length; i++) {
        snap.GetKey(i, buffer, maxValueLength);

        // Skip json meta keys.
        if (json_is_meta_key(buffer)) {
          continue;
        }

        data.GetString(buffer, name, sizeof(name));
        char steam64[AUTH_LENGTH];
        if (ConvertAuthToSteam64(buffer, steam64)) {
          Get5_SetPlayerName(steam64, name);
          list.PushString(steam64);
          count++;
        }
      }
      delete snap;
    }
  }
  return count;
}
