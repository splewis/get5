static char g_fileToUpload[PLATFORM_MAX_PATH];
static char g_uploadPath[PLATFORM_MAX_PATH];
static int g_mapNumber = 0;

public void HandleDemoUpload() {
    char ftpHost[128];
    g_DemoFtpHostCvar.GetString(ftpHost, sizeof(ftpHost));

    if (LibraryExists("system2") && !StrEqual(ftpHost, "") && !StrEqual(g_DemoFileName, "")) {
        g_mapNumber = GetMapNumber() - 1;
        Format(g_fileToUpload, sizeof(g_fileToUpload), "%s.zip", g_DemoFileName);
        LogDebug("Compressing %s into %s", g_DemoFileName, g_fileToUpload);
        System2_CompressFile(CompressionCallback, g_DemoFileName, g_fileToUpload);
    } else {
        LogDebug("Skipping demo upload, %d, %s, %s", LibraryExists("system2"), ftpHost, g_DemoFileName);
    }
}

public int CompressionCallback(const char[] output, const int size, CMDReturn status) {
    if (status == CMD_SUCCESS) {
        UploadFile(g_fileToUpload);
    } else if (status == CMD_ERROR) {
        LogError("Failed to compress demo: %s", output);
    }
}

public void UploadFile(const char[] file) {
    char ftpHost[128];
    char ftpUser[128];
    char ftpPassword[128];
    int port = 21;
    char demoPath[128];

    g_DemoFtpHostCvar.GetString(ftpHost, sizeof(ftpHost));
    g_DemoFtpUserCvar.GetString(ftpUser, sizeof(ftpUser));
    g_DemoFtpPasswordCvar.GetString(ftpPassword, sizeof(ftpPassword));
    port = g_DemoFtpPortCvar.IntValue;
    g_DemoFtpPathCvar.GetString(demoPath, sizeof(demoPath));

    Format(g_uploadPath, sizeof(g_uploadPath), "%s/%s", demoPath, file);
    LogDebug("FTP upload %s to %s on %s:%d", file, g_uploadPath, ftpHost, port);
    System2_UploadFTPFile(UploadCallback, file, g_uploadPath, ftpHost, ftpUser, ftpPassword, port);
}

public int UploadCallback(bool finished, const char[] error, float dltotal, float dlnow, float ultotal, float ulnow) {
    if (finished) {
        if (StrEqual(error, "")) {
            LogDebug("Finished upload");
            if (g_DemoDeleteAfterUploadCvar.IntValue != 0) {
                DeleteFile(g_DemoFileName);
                DeleteFile(g_fileToUpload);
            }
            Call_StartForward(g_OnDemoUploaded);
            Call_PushString(g_MatchID);
            Call_PushCell(g_mapNumber);
            Call_PushString(g_fileToUpload);
            Call_PushString(g_uploadPath);
            Call_Finish();
        } else {
            LogError("Error uploading demo: %s", error);
        }
    }
}
