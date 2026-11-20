/**
 * @file main.c
 * @brief Native Windows Lua host for Card Forge Engine.
 * Resolves the root from Bin/Windows and executes root init.lua using the parent Studio Lua 5.4 runtime.
 */
#define UNICODE
#define _UNICODE
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0602
#endif
#include <windows.h>
#include <shellapi.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

typedef struct lua_State lua_State;
typedef intptr_t lua_KContext;
typedef int (*lua_KFunction)(lua_State *, int, lua_KContext);

static wchar_t Root[32768];
static int Quiet;

/** @brief Logs a UTF-8 startup error and displays it for interactive launches. */
static int reportError(const char *message)
{
    wchar_t path[32768], text[8192];
    FILE *file;

    if (swprintf(path, 32768, L"%ls/Bin/Windows/card-forge-engine-error.log", Root) > 0)
    {
        file = _wfopen(path, L"ab");
        if (file != NULL) { fprintf(file, "%s\n", message); fclose(file); }
    }

    if (!Quiet)
    {
        if (!MultiByteToWideChar(CP_UTF8, 0, message, -1, text, 8192))
        {
            wcscpy(text, L"Card Forge Engine startup failed. See Bin/Windows/card-forge-engine-error.log.");
        }
        MessageBoxW(NULL, text, L"Card Forge Engine", MB_OK | MB_ICONERROR);
    }
    return 1;
}

/**
 * @brief Loads the selected wxLua runtime and executes CFE/init.lua.
 * @return Zero after normal shutdown, nonzero for startup or application errors.
 */
int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR command, int show)
{
    wchar_t bin[32768], libraryPath[32768], **arguments, *separator;
    HMODULE library;
    DLL_DIRECTORY_COOKIE directory;
    DWORD length, runtimeLength;
    int count, index, status = 1;
    lua_State *state = NULL;

    lua_State *(*newState)(void);
    void (*openLibraries)(lua_State *);
    const char *(*pushString)(lua_State *, const char *, size_t);
    void (*setGlobal)(lua_State *, const char *);
    void (*createTable)(lua_State *, int, int);
    void (*rawSetIndex)(lua_State *, int, int64_t);
    int (*loadString)(lua_State *, const char *);
    int (*call)(lua_State *, int, int, int, lua_KContext, lua_KFunction);
    const char *(*toString)(lua_State *, int, size_t *);
    void (*closeState)(lua_State *) = NULL;

    (void)instance; (void)previous; (void)command; (void)show;
    arguments = CommandLineToArgvW(GetCommandLineW(), &count);
    if (arguments == NULL) { return reportError("Cannot read command-line arguments."); }
    for (index = 1; index < count; ++index)
    {
        if (wcscmp(arguments[index], L"--smoke") == 0 ||
            wcscmp(arguments[index], L"--check") == 0) { Quiet = 1; }
    }

    length = GetModuleFileNameW(NULL, Root, 32768);
    if (length == 0 || length >= 32768) { LocalFree(arguments); return reportError("Cannot locate the Card Forge Engine executable."); }

    /* Executable -> Windows -> Bin -> CFE. Paths do not depend on the caller. */
    for (index = 0; index < 3; ++index)
    {
        separator = wcsrchr(Root, L'\\');
        if (separator == NULL) { LocalFree(arguments); return reportError("Invalid Card Forge Engine installation layout."); }
        *separator = L'\0';
    }

    /* Studio owns the common DLL set. Canonicalize it before registering it. */
    if (swprintf(libraryPath, 32768, L"%ls\\..\\Bin", Root) < 0)
    {
        LocalFree(arguments);
        return reportError("Card Forge Studio runtime path is too long.");
    }
    runtimeLength = GetFullPathNameW(libraryPath, 32768, bin, NULL);
    if (runtimeLength == 0 || runtimeLength >= 32768 ||
        swprintf(libraryPath, 32768, L"%ls\\lua54.dll", bin) < 0)
    {
        LocalFree(arguments);
        return reportError("Card Forge Engine installation path is too long.");
    }
    if (!SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_DEFAULT_DIRS))
    {
        LocalFree(arguments);
        return reportError("Cannot configure DLL lookup.");
    }
    directory = AddDllDirectory(bin);
    if (directory == NULL) { LocalFree(arguments); return reportError("Cannot select the runtime directory."); }
    library = LoadLibraryExW(libraryPath, NULL, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
    if (library == NULL)
    {
        RemoveDllDirectory(directory);
        LocalFree(arguments);
        return reportError("Cannot load lua54.dll from the parent Card Forge Studio/Bin folder. Check the Studio installation.");
    }

    /* Bind the stable C ABI without a toolchain-specific Lua import library. */
#define BIND(target, name) do { \
    FARPROC address = GetProcAddress(library, name); \
    if (address == NULL) { reportError("Missing Lua 5.4 API: " name); goto cleanup; } \
    _Static_assert(sizeof(target) == sizeof(address), "Function pointer size mismatch"); \
    memcpy(&(target), &address, sizeof(target)); \
} while (0)

    BIND(newState, "luaL_newstate");
    BIND(openLibraries, "luaL_openlibs");
    BIND(pushString, "lua_pushlstring");
    BIND(setGlobal, "lua_setglobal");
    BIND(createTable, "lua_createtable");
    BIND(rawSetIndex, "lua_rawseti");
    BIND(loadString, "luaL_loadstring");
    BIND(call, "lua_pcallk");
    BIND(toString, "lua_tolstring");
    BIND(closeState, "lua_close");

    state = newState();
    if (state == NULL) { reportError("Cannot create the Lua environment."); goto cleanup; }
    openLibraries(state);

    /* Paths and arguments are Lua strings, never interpolated executable code. */
    for (index = -2; index < count; ++index)
    {
        const wchar_t *value = index == -2 ? bin : (index == -1 ? Root : arguments[index]);
        int bytes = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value, -1, NULL, 0, NULL, NULL);
        char *utf8;

        if (bytes == 0) { reportError("Cannot encode a path or argument."); goto cleanup; }
        utf8 = (char *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)bytes);
        if (utf8 == NULL) { reportError("Cannot allocate argument storage."); goto cleanup; }
        WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value, -1, utf8, bytes, NULL, NULL);
        pushString(state, utf8, (size_t)(bytes - 1));
        HeapFree(GetProcessHeap(), 0, utf8);
        if (index == -2) { setGlobal(state, "CARD_FORGE_ENGINE_RUNTIME"); }
        else if (index == -1)
        {
            setGlobal(state, "CARD_FORGE_ENGINE_ROOT");
            createTable(state, count, 0);
        }
        else { rawSetIndex(state, -2, index); }
    }
    setGlobal(state, "arg");

    status = loadString(state,
        "CARD_FORGE_ENGINE_ROOT=CARD_FORGE_ENGINE_ROOT:gsub('\\\\','/'); "
        "package.path=CARD_FORGE_ENGINE_ROOT..'/?.lua;'..CARD_FORGE_ENGINE_ROOT..'/?/init.lua'; "
        "package.cpath=CARD_FORGE_ENGINE_RUNTIME:gsub('\\\\','/')..'/?.dll'; "
        "local ok,err=xpcall(function() assert(loadfile(CARD_FORGE_ENGINE_ROOT..'/init.lua'))() end,debug.traceback); "
        "if not ok then error(err,0) end");
    if (status == 0) { status = call(state, 0, 0, 0, 0, NULL); }
    if (status != 0)
    {
        const char *message = toString(state, -1, NULL);
        reportError(message == NULL ? "Card Forge Engine failed with a non-text Lua error." : message);
    }

cleanup:
    if (state != NULL && closeState != NULL) { closeState(state); }
    FreeLibrary(library);
    RemoveDllDirectory(directory);
    LocalFree(arguments);
    return status == 0 ? 0 : 1;
}
