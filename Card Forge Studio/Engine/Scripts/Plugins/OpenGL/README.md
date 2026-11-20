# OpenGL for Lua

Reusable OpenGL 3.3 quad rendering bridge. It has no CFE, LuaEx, wxLua or
wxWidgets dependency. Any compatible Lua 5.4 host can supply a native window
handle and drive its own event loop. The included Windows x64 build links to
`lua54.dll`; it was built against the official Lua 5.4.8 headers.

Only the Windows backend is implemented and tested. Linux and macOS are not
implemented. A driver capable of OpenGL 3.3 core is required; there is no silent
software fallback. This is a textured-quad renderer with custom shaders, not a
complete binding of every OpenGL function or a general mesh engine.

## Ownership

Give `OpenGL.create(handle)` a dedicated native HWND as light userdata. For
wxLua, a `wxPanel:GetHandle()` supplies it. The host owns the window and event
loop. The plugin selects its pixel format and creates/owns a WGL context. Do not
attach another graphics system to that same window or change its pixel format.

Use all methods on the creating thread. **Call `renderer:close()` before the
host window is destroyed.** Close is idempotent; it releases the device context,
OpenGL context, shaders, textures and internal geometry. A finalizer provides
backup cleanup, but explicit close is required for predictable window lifetime.
Resource handles retain their owning context. Handles are context-specific and
are rejected after release or close. GPU objects remain context-owned until
`release(handle)` or `close()`; dropping a handle alone does not release it.

Operations make their context current and do not restore a previously current
context. Other rendering systems must make their own context current afterward.
Draw order is painter order: alpha blending is enabled, depth testing/culling
are disabled. The bridge draws six vertices forming a centered unit quad.

## API

```lua
local OpenGL = require("OpenGL");
local oRenderer = OpenGL.create(oPanel:GetHandle());
local uProgram = oRenderer:createProgram(OpenGL.VertexShader, OpenGL.FragmentShader);
local uTexture = oRenderer:createTexture(1, 1, string.char(255, 255, 255, 255));
oRenderer:beginFrame(800, 600, 0.02, 0.03, 0.05);
oRenderer:draw(uProgram, uTexture,
    OpenGL.transform(400, 300, 180, 270, 0, 0, 800, 600),
    {0.2, 0.8, 1, 1});
oRenderer:present();
-- Before destroying oPanel:
oRenderer:close();
```

- `create(handle)` creates the renderer; fails explicitly if the driver cannot
  create OpenGL 3.3 core.
- `clock()` returns monotonic high-resolution seconds for animation timing.
- `renderer:info()` returns Vendor, Renderer, Version and ShaderVersion.
- `createProgram(vertexSource, fragmentSource)` compiles GLSL and reports compiler
  or linker diagnostics. Attribute locations 0/1 are position (vec3) and UV (vec2).
- `createTexture(width, height, bytes [, alpha])` accepts packed RGBA or RGB.
  RGB optionally takes one alpha byte per pixel; otherwise it is opaque. Rows
  are top-down for the supplied transform/shader. Textures use trilinear mipmaps
  and clamp-to-edge addressing. Keep a texture handle and reuse it every frame.
- `beginFrame(width, height, r, g, b)` sets the pixel viewport and clears it.
- `draw(program, texture, matrix, tint [, effect])` draws a quad. Matrix is 16
  column-major numbers; tint/effect are four numbers each. Shader uniforms are
  `uTransform`, `uTexture`, `uTint`, and `uEffect`. Custom programs may omit unused
  uniforms. Default effect modes: 0 textured; 1 soft rectangle; 2 ring (Y is
  normalized radius); 3 radial glow. Tint and blending use straight alpha.
- `OpenGL.transform(x, y, width, height, angle, flip, viewWidth, viewHeight)`
  creates a matrix with top-left screen coordinates, centered position, Z
  rotation and perspective Y rotation. Angles are radians. Flips beyond 90
  degrees reverse the quad; choose back artwork/orientation in the host.
- `present()` checks GL errors and swaps the window buffers. Requests vsync when
  the driver exposes swap-interval control; actual scheduling is driver-dependent.
- `readPixels(width, height)` returns bottom-up RGBA bytes from the back buffer,
  **before** present. Intended for verification, not routine rendering.
- `release(handle)` explicitly releases a shader program or texture; repeat calls
  are harmless while the context is open.
- `close()` releases the context and its GPU resources.

## Build

`src/BuildWindows.ps1` uses an installed LLVM-MinGW toolchain and an official Lua
5.4 SDK matching the host ABI. It generates the import library from the supplied
host DLL exports, compiles with warnings treated as errors, and prints imports.
It does not download or install tools. Build into a temporary staging directory:

```powershell
./src/BuildWindows.ps1 -CompilerBin '<llvm-mingw>/bin' `
    -LuaSource '<lua-5.4.8>/src' -LuaRuntime '<host>/lua54.dll' `
    -Stage '<temporary-build-directory>'
```

After verification, copy the resulting `opengl.dll` to `bin/windows-x64/`.
The current binary was built with LLVM-MinGW Clang 14.0.6. Its imports are the
host `lua54.dll` and Windows OpenGL/GDI/User/CRT/kernel libraries. No compiler
installation or wxWidgets C++ ABI is required by the installed binary.

## Verification

Run from a directory where the host Lua/wxLua DLL dependencies resolve:

```powershell
./lua.exe '<plugin>/tests/Verify.lua' '<folder-containing-OpenGL>'
```

The test uses wxLua solely to provide disposable native windows. It checks
shader errors, texture dimensions/data, RGB and RGBA uploads, alpha blending
by framebuffer readback, resource isolation across contexts, release guards,
buffer swap and explicit cleanup. Windows x64 was verified on an NVIDIA
GeForce RTX 3060 Ti with an OpenGL 3.3 core context. Other GPUs are unverified.