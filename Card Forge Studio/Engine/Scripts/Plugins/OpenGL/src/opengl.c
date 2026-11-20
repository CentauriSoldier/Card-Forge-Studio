/* Reusable Lua 5.4 OpenGL quad renderer. The host owns the native window.
 * This Windows backend owns its WGL context and all graphics resources.
 * No wxWidgets, wxLua, LuaEx or application ABI is used here. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <GL/gl.h>
#include <GL/glext.h>
#include <lua.h>
#include <lauxlib.h>
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define CONTEXT "OpenGL.Context"
#define RESOURCE "OpenGL.Resource"
#define LOAD(member, type, name) do { c->member = (type)wglGetProcAddress(name); \
    if (!validProc((PROC)c->member)) { closeContext(c); return luaL_error(L, "Missing OpenGL function: %s", name); } } while (0)

typedef struct Resource {
    GLuint id;
    GLenum kind;
    struct Resource *next;
} Resource;
typedef struct Context {
    HWND window;
    HDC dc;
    HGLRC rc;
    DWORD thread;
    GLuint vao, buffer;
    Resource *resources;
    int width, height;
    PFNGLGENVERTEXARRAYSPROC genVertexArrays;
    PFNGLBINDVERTEXARRAYPROC bindVertexArray;
    PFNGLDELETEVERTEXARRAYSPROC deleteVertexArrays;
    PFNGLGENBUFFERSPROC genBuffers;
    PFNGLBINDBUFFERPROC bindBuffer;
    PFNGLBUFFERDATAPROC bufferData;
    PFNGLDELETEBUFFERSPROC deleteBuffers;
    PFNGLVERTEXATTRIBPOINTERPROC vertexAttribPointer;
    PFNGLENABLEVERTEXATTRIBARRAYPROC enableVertexAttribArray;
    PFNGLCREATESHADERPROC createShader;
    PFNGLSHADERSOURCEPROC shaderSource;
    PFNGLCOMPILESHADERPROC compileShader;
    PFNGLGETSHADERIVPROC getShaderiv;
    PFNGLGETSHADERINFOLOGPROC getShaderInfoLog;
    PFNGLDELETESHADERPROC deleteShader;
    PFNGLCREATEPROGRAMPROC createProgram;
    PFNGLATTACHSHADERPROC attachShader;
    PFNGLLINKPROGRAMPROC linkProgram;
    PFNGLGETPROGRAMIVPROC getProgramiv;
    PFNGLGETPROGRAMINFOLOGPROC getProgramInfoLog;
    PFNGLDELETEPROGRAMPROC deleteProgram;
    PFNGLUSEPROGRAMPROC useProgram;
    PFNGLGETUNIFORMLOCATIONPROC getUniformLocation;
    PFNGLUNIFORMMATRIX4FVPROC uniformMatrix4fv;
    PFNGLUNIFORM4FVPROC uniform4fv;
    PFNGLUNIFORM1IPROC uniform1i;
    PFNGLACTIVETEXTUREPROC activeTexture;
    PFNGLGENERATEMIPMAPPROC generateMipmap;
} Context;
typedef struct Handle { Context *owner; Resource *resource; } Handle;
typedef HGLRC (WINAPI *CreateContextAttribs)(HDC, HGLRC, const int *);
typedef BOOL (WINAPI *SwapInterval)(int);

static int validProc(PROC p) {
    return p && p != (PROC)(intptr_t)1 && p != (PROC)(intptr_t)2 &&
        p != (PROC)(intptr_t)3 && p != (PROC)(intptr_t)-1;
}
static Context *current(lua_State *L) {
    Context *c = (Context *)luaL_checkudata(L, 1, CONTEXT);
    luaL_argcheck(L, c->rc != NULL, 1, "OpenGL context is closed");
    luaL_argcheck(L, c->thread == GetCurrentThreadId(), 1, "Use the creating thread");
    luaL_argcheck(L, IsWindow(c->window), 1, "Host window was destroyed before its context");
    if (!wglMakeCurrent(c->dc, c->rc)) luaL_error(L, "Cannot make OpenGL context current");
    return c;
}
static Resource *resource(lua_State *L, Context *c, int index, GLenum kind) {
    Handle *h = (Handle *)luaL_checkudata(L, index, RESOURCE);
    luaL_argcheck(L, h->owner == c && h->resource->kind == kind && h->resource->id,
        index, "Wrong context, resource type, or released resource");
    return h->resource;
}
static Resource *newResource(lua_State *L, Context *c, GLenum kind) {
    Handle *h = (Handle *)lua_newuserdatauv(L, sizeof(Handle), 1);
    memset(h, 0, sizeof(*h));
    luaL_setmetatable(L, RESOURCE);
    lua_pushvalue(L, 1);
    lua_setiuservalue(L, -2, 1); /* Resource keeps its owning context alive. */
    Resource *r = (Resource *)calloc(1, sizeof(Resource));
    if (!r) luaL_error(L, "Cannot allocate OpenGL resource");
    r->kind = kind; r->next = c->resources; c->resources = r;
    h->owner = c; h->resource = r;
    return r;
}
static void closeContext(Context *c) {
    if (c->rc) {
        if (wglMakeCurrent(c->dc, c->rc)) {
            for (Resource *r = c->resources; r; r = r->next) {
                if (r->id && r->kind == GL_TEXTURE_2D) glDeleteTextures(1, &r->id);
                if (r->id && r->kind == GL_PROGRAM && c->deleteProgram) c->deleteProgram(r->id);
                r->id = 0;
            }
            if (c->vao && c->deleteVertexArrays) c->deleteVertexArrays(1, &c->vao);
            if (c->buffer && c->deleteBuffers) c->deleteBuffers(1, &c->buffer);
            wglMakeCurrent(NULL, NULL);
        }
        wglDeleteContext(c->rc); c->rc = NULL;
    }
    if (c->dc) { ReleaseDC(c->window, c->dc); c->dc = NULL; }
}
static int closeRenderer(lua_State *L) {
    Context *c = (Context *)luaL_checkudata(L, 1, CONTEXT);
    luaL_argcheck(L, c->thread == GetCurrentThreadId(), 1, "Use the creating thread");
    closeContext(c);
    return 0;
}
static int collectContext(lua_State *L) {
    Context *c = (Context *)luaL_checkudata(L, 1, CONTEXT);
    closeContext(c);
    while (c->resources) { Resource *next = c->resources->next; free(c->resources); c->resources = next; }
    return 0;
}
static int failContext(lua_State *L, Context *c, const char *message) {
    closeContext(c);
    return luaL_error(L, "%s", message);
}
static int create(lua_State *L) {
    luaL_argcheck(L, lua_islightuserdata(L, 1), 1, "Expected a native HWND as light userdata");
    HWND window = (HWND)lua_touserdata(L, 1);
    luaL_argcheck(L, IsWindow(window), 1, "Invalid native window");
    Context *c = (Context *)lua_newuserdatauv(L, sizeof(Context), 0);
    memset(c, 0, sizeof(*c));
    luaL_setmetatable(L, CONTEXT);
    c->window = window; c->thread = GetCurrentThreadId(); c->dc = GetDC(window);
    if (!c->dc) return failContext(L, c, "Cannot acquire the window device context");
    PIXELFORMATDESCRIPTOR format = {0};
    format.nSize = sizeof(format); format.nVersion = 1;
    format.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
    format.iPixelType = PFD_TYPE_RGBA; format.cColorBits = 32; format.cAlphaBits = 8;
    format.cDepthBits = 24; format.cStencilBits = 8;
    int pixelFormat = GetPixelFormat(c->dc);
    if (!pixelFormat) {
        pixelFormat = ChoosePixelFormat(c->dc, &format);
        if (!pixelFormat || !SetPixelFormat(c->dc, pixelFormat, &format))
            return failContext(L, c, "Cannot set an OpenGL window pixel format");
    }
    c->rc = wglCreateContext(c->dc);
    if (!c->rc || !wglMakeCurrent(c->dc, c->rc))
        return failContext(L, c, "Cannot create a bootstrap OpenGL context");
    CreateContextAttribs createModern = (CreateContextAttribs)wglGetProcAddress("wglCreateContextAttribsARB");
    if (!validProc((PROC)createModern)) return failContext(L, c, "Driver does not expose OpenGL 3.3 context creation");
    const int attributes[] = {0x2091, 3, 0x2092, 3, 0x9126, 1, 0};
    HGLRC modern = createModern(c->dc, NULL, attributes);
    if (!modern) return failContext(L, c, "Driver refused an OpenGL 3.3 core context");
    wglMakeCurrent(NULL, NULL); wglDeleteContext(c->rc); c->rc = modern;
    if (!wglMakeCurrent(c->dc, c->rc)) return failContext(L, c, "Cannot activate OpenGL 3.3");
    LOAD(genVertexArrays, PFNGLGENVERTEXARRAYSPROC, "glGenVertexArrays");
    LOAD(bindVertexArray, PFNGLBINDVERTEXARRAYPROC, "glBindVertexArray");
    LOAD(deleteVertexArrays, PFNGLDELETEVERTEXARRAYSPROC, "glDeleteVertexArrays");
    LOAD(genBuffers, PFNGLGENBUFFERSPROC, "glGenBuffers");
    LOAD(bindBuffer, PFNGLBINDBUFFERPROC, "glBindBuffer");
    LOAD(bufferData, PFNGLBUFFERDATAPROC, "glBufferData");
    LOAD(deleteBuffers, PFNGLDELETEBUFFERSPROC, "glDeleteBuffers");
    LOAD(vertexAttribPointer, PFNGLVERTEXATTRIBPOINTERPROC, "glVertexAttribPointer");
    LOAD(enableVertexAttribArray, PFNGLENABLEVERTEXATTRIBARRAYPROC, "glEnableVertexAttribArray");
    LOAD(createShader, PFNGLCREATESHADERPROC, "glCreateShader");
    LOAD(shaderSource, PFNGLSHADERSOURCEPROC, "glShaderSource");
    LOAD(compileShader, PFNGLCOMPILESHADERPROC, "glCompileShader");
    LOAD(getShaderiv, PFNGLGETSHADERIVPROC, "glGetShaderiv");
    LOAD(getShaderInfoLog, PFNGLGETSHADERINFOLOGPROC, "glGetShaderInfoLog");
    LOAD(deleteShader, PFNGLDELETESHADERPROC, "glDeleteShader");
    LOAD(createProgram, PFNGLCREATEPROGRAMPROC, "glCreateProgram");
    LOAD(attachShader, PFNGLATTACHSHADERPROC, "glAttachShader");
    LOAD(linkProgram, PFNGLLINKPROGRAMPROC, "glLinkProgram");
    LOAD(getProgramiv, PFNGLGETPROGRAMIVPROC, "glGetProgramiv");
    LOAD(getProgramInfoLog, PFNGLGETPROGRAMINFOLOGPROC, "glGetProgramInfoLog");
    LOAD(deleteProgram, PFNGLDELETEPROGRAMPROC, "glDeleteProgram");
    LOAD(useProgram, PFNGLUSEPROGRAMPROC, "glUseProgram");
    LOAD(getUniformLocation, PFNGLGETUNIFORMLOCATIONPROC, "glGetUniformLocation");
    LOAD(uniformMatrix4fv, PFNGLUNIFORMMATRIX4FVPROC, "glUniformMatrix4fv");
    LOAD(uniform4fv, PFNGLUNIFORM4FVPROC, "glUniform4fv");
    LOAD(uniform1i, PFNGLUNIFORM1IPROC, "glUniform1i");
    LOAD(activeTexture, PFNGLACTIVETEXTUREPROC, "glActiveTexture");
    LOAD(generateMipmap, PFNGLGENERATEMIPMAPPROC, "glGenerateMipmap");
    const GLfloat vertices[] = {
        -.5f,-.5f,0, 0,0,  .5f,-.5f,0, 1,0,  .5f,.5f,0, 1,1,
        -.5f,-.5f,0, 0,0,  .5f,.5f,0, 1,1,  -.5f,.5f,0, 0,1
    };
    c->genVertexArrays(1, &c->vao); c->bindVertexArray(c->vao);
    c->genBuffers(1, &c->buffer); c->bindBuffer(GL_ARRAY_BUFFER, c->buffer);
    c->bufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    c->vertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), NULL);
    c->vertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), (const void *)(3 * sizeof(GLfloat)));
    c->enableVertexAttribArray(0); c->enableVertexAttribArray(1);
    glEnable(GL_BLEND); glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_DEPTH_TEST); glDisable(GL_CULL_FACE);
    SwapInterval swapInterval = (SwapInterval)wglGetProcAddress("wglSwapIntervalEXT");
    if (validProc((PROC)swapInterval)) swapInterval(1);
    if (glGetError() != GL_NO_ERROR) return failContext(L, c, "OpenGL renderer initialization failed");
    return 1;
}
static int info(lua_State *L) {
    current(L); lua_newtable(L);
    const GLenum keys[] = {GL_VENDOR, GL_RENDERER, GL_VERSION, GL_SHADING_LANGUAGE_VERSION};
    const char *names[] = {"Vendor", "Renderer", "Version", "ShaderVersion"};
    for (int i = 0; i < 4; ++i) { lua_pushstring(L, (const char *)glGetString(keys[i])); lua_setfield(L, -2, names[i]); }
    return 1;
}
static GLuint compile(lua_State *L, Context *c, GLenum kind, const char *source) {
    GLuint shader = c->createShader(kind);
    c->shaderSource(shader, 1, &source, NULL); c->compileShader(shader);
    GLint success = 0; c->getShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char log[4096] = {0}; c->getShaderInfoLog(shader, sizeof(log), NULL, log);
        c->deleteShader(shader); luaL_error(L, "Shader compilation failed: %s", log);
    }
    return shader;
}
static int createProgram(lua_State *L) {
    Context *c = current(L);
    const char *vertex = luaL_checkstring(L, 2), *fragment = luaL_checkstring(L, 3);
    Resource *r = newResource(L, c, GL_PROGRAM);
    r->id = c->createProgram();
    GLuint vs = compile(L, c, GL_VERTEX_SHADER, vertex);
    c->attachShader(r->id, vs); c->deleteShader(vs);
    GLuint fs = compile(L, c, GL_FRAGMENT_SHADER, fragment);
    c->attachShader(r->id, fs); c->deleteShader(fs);
    c->linkProgram(r->id);
    GLint success = 0; c->getProgramiv(r->id, GL_LINK_STATUS, &success);
    if (!success) {
        char log[4096] = {0}; c->getProgramInfoLog(r->id, sizeof(log), NULL, log);
        c->deleteProgram(r->id); r->id = 0;
        return luaL_error(L, "Shader link failed: %s", log);
    }
    return 1;
}
static int dimension(lua_State *L, int index, int maximum) {
    lua_Integer value = luaL_checkinteger(L, index);
    luaL_argcheck(L, value > 0 && value <= maximum, index, "Dimension outside supported range");
    return (int)value;
}
static int createTexture(lua_State *L) {
    Context *c = current(L); GLint limit = 0; glGetIntegerv(GL_MAX_TEXTURE_SIZE, &limit);
    int width = dimension(L, 2, limit), height = dimension(L, 3, limit);
    size_t size = 0; const char *pixels = luaL_checklstring(L, 4, &size);
    size_t count = (size_t)width * height;
    luaL_argcheck(L, size == count * 4 || size == count * 3, 4, "Expected tightly packed RGB or RGBA bytes");
    if (size == count * 3) {
        size_t alphaSize = 0;
        const char *alpha = lua_isnoneornil(L, 5) ? NULL : luaL_checklstring(L, 5, &alphaSize);
        luaL_argcheck(L, !alpha || alphaSize == count, 5, "Expected one alpha byte per pixel");
        unsigned char *rgba = (unsigned char *)lua_newuserdatauv(L, count * 4, 0);
        for (size_t i = 0; i < count; ++i) {
            memcpy(rgba + i * 4, pixels + i * 3, 3);
            rgba[i * 4 + 3] = alpha ? (unsigned char)alpha[i] : 255;
        }
        pixels = (const char *)rgba;
    }
    Resource *r = newResource(L, c, GL_TEXTURE_2D);
    glGenTextures(1, &r->id); glBindTexture(GL_TEXTURE_2D, r->id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    c->generateMipmap(GL_TEXTURE_2D);
    if (glGetError() != GL_NO_ERROR) { glDeleteTextures(1, &r->id); r->id = 0; return luaL_error(L, "Texture upload failed"); }
    return 1;
}
static int release(lua_State *L) {
    Context *c = current(L); Handle *h = (Handle *)luaL_checkudata(L, 2, RESOURCE);
    luaL_argcheck(L, h->owner == c, 2, "Resource belongs to another context");
    Resource *r = h->resource;
    if (r->id && r->kind == GL_TEXTURE_2D) glDeleteTextures(1, &r->id);
    if (r->id && r->kind == GL_PROGRAM) c->deleteProgram(r->id);
    r->id = 0;
    return 0;
}
static float number(lua_State *L, int index) {
    lua_Number value = luaL_checknumber(L, index);
    luaL_argcheck(L, isfinite(value) && fabs(value) <= 1e20, index, "Expected a finite graphics value");
    return (float)value;
}
static int beginFrame(lua_State *L) {
    Context *c = current(L);
    c->width = dimension(L, 2, 32768); c->height = dimension(L, 3, 32768);
    float red = number(L, 4), green = number(L, 5), blue = number(L, 6);
    glViewport(0, 0, c->width, c->height);
    glClearColor(red, green, blue, 1); glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    return 0;
}
static void vector(lua_State *L, int index, GLfloat *values, int count) {
    luaL_checktype(L, index, LUA_TTABLE);
    for (int i = 0; i < count; ++i) {
        lua_rawgeti(L, index, i + 1); values[i] = number(L, -1); lua_pop(L, 1);
    }
}
static int draw(lua_State *L) {
    Context *c = current(L);
    Resource *program = resource(L, c, 2, GL_PROGRAM), *texture = resource(L, c, 3, GL_TEXTURE_2D);
    GLfloat matrix[16], tint[4], effect[4] = {0};
    vector(L, 4, matrix, 16); vector(L, 5, tint, 4);
    if (!lua_isnoneornil(L, 6)) vector(L, 6, effect, 4);
    c->useProgram(program->id); c->bindVertexArray(c->vao); c->activeTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture->id);
    c->uniform1i(c->getUniformLocation(program->id, "uTexture"), 0);
    c->uniformMatrix4fv(c->getUniformLocation(program->id, "uTransform"), 1, GL_FALSE, matrix);
    c->uniform4fv(c->getUniformLocation(program->id, "uTint"), 1, tint);
    c->uniform4fv(c->getUniformLocation(program->id, "uEffect"), 1, effect);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    return 0;
}
static int present(lua_State *L) {
    Context *c = current(L);
    GLenum error = glGetError();
    if (error != GL_NO_ERROR) return luaL_error(L, "OpenGL frame error: %d", (int)error);
    if (!SwapBuffers(c->dc)) return luaL_error(L, "OpenGL buffer swap failed");
    return 0;
}
static int readPixels(lua_State *L) {
    Context *c = current(L);
    int width = dimension(L, 2, 32768), height = dimension(L, 3, 32768);
    luaL_argcheck(L, width <= c->width && height <= c->height, 2, "Readback exceeds the current frame");
    size_t size = (size_t)width * height * 4;
    luaL_Buffer buffer; char *pixels = luaL_buffinitsize(L, &buffer, size);
    glPixelStorei(GL_PACK_ALIGNMENT, 1); glReadBuffer(GL_BACK);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    if (glGetError() != GL_NO_ERROR) return luaL_error(L, "OpenGL readback failed");
    luaL_pushresultsize(&buffer, size); return 1;
}
static int clockSeconds(lua_State *L) {
    LARGE_INTEGER frequency, counter;
    QueryPerformanceFrequency(&frequency); QueryPerformanceCounter(&counter);
    lua_pushnumber(L, (lua_Number)counter.QuadPart / (lua_Number)frequency.QuadPart); return 1;
}
__declspec(dllexport) int luaopen_opengl(lua_State *L) {
    luaL_checkversion(L);
    const luaL_Reg methods[] = {
        {"info", info}, {"createProgram", createProgram}, {"createTexture", createTexture},
        {"release", release}, {"beginFrame", beginFrame}, {"draw", draw}, {"present", present},
        {"readPixels", readPixels}, {"close", closeRenderer}, {"__gc", collectContext}, {NULL, NULL}
    };
    luaL_newmetatable(L, CONTEXT); luaL_setfuncs(L, methods, 0);
    lua_pushvalue(L, -1); lua_setfield(L, -2, "__index"); lua_pop(L, 1);
    luaL_newmetatable(L, RESOURCE); lua_pop(L, 1);
    const luaL_Reg module[] = {{"create", create}, {"clock", clockSeconds}, {NULL, NULL}};
    luaL_newlib(L, module); return 1;
}