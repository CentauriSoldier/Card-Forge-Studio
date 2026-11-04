#define UNICODE
#define _UNICODE
#include <windows.h>
#include <shellapi.h>
#include <wchar.h>
#include <stdio.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

typedef struct LauncherConstant
{
    const char *name;
    const char *value;
} LauncherConstant;

/* Edit this collection, then rebuild. The injection loop handles every entry. */
static const LauncherConstant LAUNCHER_CONSTANTS[] = {
    {"APP_CFG",             "Card Forge Studio.cfg"},
    {"APP_GITHUB",          "https://github.com/CentauriSoldier/Card-Forge-Studio"},
    {"APP_PATREON",         "https://www.patreon.com/CentauriSoldier"},
    {"APP_WEBSITE",         "https://www.cardforge.studio/"},
    {"APP_NAME",            "Card Forge Studio"},
    {"APP_MAJOR_VERSION",   "v0."},
    {"APP_BUILD_VERSION",   ".alpha"},
};

/* Dynamic constants: APP_PATH is this EXE's folder; _AppDataLocal comes from WX. */

static void writeError(const char *message)
{
    wchar_t folder[32768];
    wchar_t path[32768];
    wchar_t *separator;
    FILE *file = NULL;
    DWORD length = GetModuleFileNameW(NULL, folder, 32768);

    if (length > 0 && length < 32768 && (separator = wcsrchr(folder, L'\\')) != NULL)
    {
        *separator = L'\0';
        if (swprintf_s(path, 32768, L"%ls\\log.log", folder) >= 0)
        {
            _wfopen_s(&file, path, L"ab");
        }
    }

    if (file == NULL && GetTempPathW(32768, folder) > 0 &&
        swprintf_s(path, 32768, L"%lsCard Forge Studio-errors.log", folder) >= 0)
    {
        _wfopen_s(&file, path, L"ab");
    }

    if (file != NULL)
    {
        fprintf(file, "[ERROR] %s\n", message);
        fclose(file);
    }
}

static int showError(const wchar_t *message, DWORD errorCode)
{
    char encoded[8192];
    char details[9216];
    if (WideCharToMultiByte(CP_UTF8, 0, message, -1, encoded, sizeof(encoded), NULL, NULL) == 0)
    {
        strcpy_s(encoded, sizeof(encoded), "Launcher error.");
    }
    sprintf_s(details, sizeof(details), "%s Windows error: %lu", encoded, errorCode);
    writeError(details);
    return 1;
}

static int pushWideString(lua_State *state, const wchar_t *value)
{
    char encoded[131072];
    int length = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value, -1, encoded, sizeof(encoded), NULL, NULL);

    if (length == 0)
    {
        return 0;
    }

    lua_pushlstring(state, encoded, (size_t)(length - 1));

    return 1;
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR arguments, int showCommand)
{
    wchar_t root[32768];
    wchar_t binaryPath[32768];
    wchar_t libraryPath[32768];
    wchar_t scriptPath[32768];
    char scriptUtf8[131072];
    wchar_t *separator;
    wchar_t **argumentList;
    DWORD length;
    HMODULE library;
    lua_State *state;
    int argumentCount;
    int status;
    int index;
    size_t constantIndex;
    const char *message;
    static const char bootstrap[] =
        "local path, protected = ...;\n"
        "protected.APP_PATH = path;\n"
        "local meta = {};\n"
        "meta.__index = function(t, key) return protected[key] end;\n"
        "meta.__newindex = function(t, key, value)\n"
        "    if protected[key] ~= nil then error(\"Attempt to overwrite protected item \"..key..\".\", 2) end\n"
        "    rawset(t, key, value);\n"
        "end;\n"
        "setmetatable(_G, meta);\n"
        "package.cpath = path..\"/Bin/?.dll;\"..package.cpath;\n"
        "local wx = require(\"wx\");\n"
        "wx.wxGetApp():SetAppName(protected.APP_NAME);\n"
        "\n"
        "local pAppData = wx.wxStandardPaths.Get():GetUserLocalDataDir();\n"
        "local oQuiet   = wx.wxLogNull();\n"
        "local bAccess  = false;\n"
        "\n"
        "if (pAppData ~= \"\" and (wx.wxDirExists(pAppData) or wx.wxFileName.Mkdir(pAppData, 511, wx.wxPATH_MKDIR_FULL))) then\n"
        "    local oDirectory = wx.wxDir(pAppData);\n"
        "    local oProbe     = wx.wxFile();\n"
        "    local pProbe     = wx.wxFileName.CreateTempFileName(pAppData..\"/cfs-access-\", oProbe);\n"
        "\n"
        "    bAccess = oDirectory:IsOpened() and pProbe ~= \"\" and oProbe:IsOpened();\n"
        "\n"
        "    oProbe:Close();\n"
        "    oProbe:delete();\n"
        "    oDirectory:delete();\n"
        "\n"
        "    if (pProbe ~= \"\") then\n"
        "        bAccess = wx.wxRemoveFile(pProbe) and bAccess;\n"
        "    end\n"
        "end\n"
        "\n"
        "oQuiet:delete();\n"
        "\n"
        "assert(bAccess, \"Card Forge Studio must terminate because its application data folder cannot be accessed for reading and writing. Check your folder permissions and available storage. Folder: \"..(pAppData ~= \"\" and pAppData or \"unavailable\"));\n"
        "protected._AppDataLocal = pAppData;\n"
        "\n"
        "\n";

    (void)instance;
    (void)previous;
    (void)arguments;
    (void)showCommand;

    length = GetModuleFileNameW(NULL, root, 32768);

    if (length == 0 || length >= 32768)
    {
        return showError(L"Cannot locate the application folder.", GetLastError());
    }

    separator = wcsrchr(root, L'\\');

    if (separator == NULL)
    {
        return showError(L"Cannot determine the application folder.", ERROR_BAD_PATHNAME);
    }

    *separator = L'\0';

    if (swprintf_s(binaryPath, 32768, L"%ls\\Bin", root) < 0 ||
        swprintf_s(libraryPath, 32768, L"%ls\\lua54.dll", binaryPath) < 0 ||
        swprintf_s(scriptPath, 32768, L"%ls\\Scripts\\init.lua", root) < 0)
    {
        return showError(L"The application path is too long.", ERROR_BUFFER_OVERFLOW);
    }

    if (!SetDllDirectoryW(binaryPath) || !SetCurrentDirectoryW(root))
    {
        return showError(L"Cannot initialize application directories.", GetLastError());
    }

    library = LoadLibraryW(libraryPath);

    if (library == NULL)
    {
        return showError(L"Cannot load Bin\\lua54.dll.", GetLastError());
    }

    state = luaL_newstate();

    if (state == NULL)
    {
        return showError(L"Cannot create the Lua environment.", ERROR_NOT_ENOUGH_MEMORY);
    }

    luaL_openlibs(state);
    status = luaL_loadstring(state, bootstrap);

    if (status == LUA_OK && pushWideString(state, root))
    {
        lua_newtable(state);

        for (constantIndex = 0; constantIndex < sizeof(LAUNCHER_CONSTANTS) / sizeof(LAUNCHER_CONSTANTS[0]); ++constantIndex)
        {
            lua_pushstring(state, LAUNCHER_CONSTANTS[constantIndex].value);
            lua_setfield(state, -2, LAUNCHER_CONSTANTS[constantIndex].name);
        }

        status = lua_pcall(state, 2, 0, 0);
    }
    else if (status == LUA_OK)
    {
        lua_close(state);
        return showError(L"Cannot encode the application folder.", GetLastError());
    }

    if (status == LUA_OK)
    {
        argumentList = CommandLineToArgvW(GetCommandLineW(), &argumentCount);

        if (argumentList == NULL)
        {
            lua_close(state);
            return showError(L"Cannot read application arguments.", GetLastError());
        }

        lua_newtable(state);

        for (index = 0; index < argumentCount; ++index)
        {
            if (!pushWideString(state, index == 0 ? scriptPath : argumentList[index]))
            {
                LocalFree(argumentList);
                lua_close(state);
                return showError(L"Cannot encode application arguments.", GetLastError());
            }

            lua_rawseti(state, -2, index);
        }

        lua_setglobal(state, "arg");
        LocalFree(argumentList);

        if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, scriptPath, -1, scriptUtf8, sizeof(scriptUtf8), NULL, NULL) == 0)
        {
            lua_close(state);
            return showError(L"Cannot encode the startup script path.", GetLastError());
        }

        status = luaL_loadfile(state, scriptUtf8);

        if (status == LUA_OK)
        {
            status = lua_pcall(state, 0, LUA_MULTRET, 0);
        }
    }

    if (status != LUA_OK)
    {
        message = lua_tostring(state, -1);
        writeError(message == NULL ? "Lua startup failed." : message);
    }

    lua_close(state);

    return status == LUA_OK ? 0 : 1;
}
