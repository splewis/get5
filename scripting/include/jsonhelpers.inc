stock bool json_has_key(Handle hObj, const char[] key) {
    Handle h = json_object_get(hObj, key);
    if (h == INVALID_HANDLE) {
        return false;
    } else {
        CloseHandle(h);
        return true;
    }
}

stock int json_object_get_string_safe(Handle hObj, const char[] key, char[] buffer,
    int maxlength, const char[] defaultValue="") {
    if (json_has_key(hObj, key)) {
        return json_object_get_string(hObj, key, buffer, maxlength);
    } else {
        return strcopy(buffer, maxlength, defaultValue);
    }
}


stock int json_object_get_int_safe(Handle hObj, const char[] key, int defaultValue=0) {
    if (json_has_key(hObj, key)) {
        return json_object_get_int(hObj, key);
    } else {
        return defaultValue;
    }
}

stock int JsonSubsectionArrayToList(Handle json, const char[] key, ArrayList list, int maxValueLength) {
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
