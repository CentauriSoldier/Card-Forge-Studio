--[[!
@fqxn OpenGL
@desc Reusable OpenGL 3.3 quad renderer for Lua 5.4. Hosts supply a native window
    and own their event loop. The native context owns all GPU resources.
!]]
local _pSource = debug.getinfo(1, "S").source:sub(2);
local _pRoot   = assert(_pSource:match("^(.*)[/\\]"), "Cannot resolve OpenGL plugin path.");
assert(package.config:sub(1, 1) == "\\" and string.packsize("j") == 8,
    "This OpenGL build supports Windows x64. Other platform backends are not installed.");
local _Native = assert(package.loadlib(_pRoot.."/bin/windows-x64/opengl.dll", "luaopen_opengl"))();
local OpenGL = {create = _Native.create, clock = _Native.clock};

OpenGL.VertexShader = [[#version 330 core
layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec2 aUV;
uniform mat4 uTransform;
out vec2 vUV;
void main() { vUV = aUV; gl_Position = uTransform * vec4(aPosition, 1.0); }
]];
OpenGL.FragmentShader = [[#version 330 core
in vec2 vUV;
uniform sampler2D uTexture;
uniform vec4 uTint;
uniform vec4 uEffect;
out vec4 outColour;
void main() {
    vec4 colour = texture(uTexture, vUV) * uTint;
    if (uEffect.x > 0.5 && uEffect.x < 1.5) {
        vec2 p = abs(vUV - 0.5) * 2.0;
        float edge = max(p.x, p.y);
        colour.a *= (1.0 - smoothstep(0.65, 1.0, edge));
    } else if (uEffect.x > 1.5 && uEffect.x < 2.5) {
        float radius = length(vUV - 0.5) * 2.0;
        colour.a *= (1.0 - smoothstep(0.04, 0.12, abs(radius - uEffect.y)));
    } else if (uEffect.x > 2.5) {
        float radius = length(vUV - 0.5) * 2.0;
        colour.a *= 1.0 - smoothstep(0.0, 1.0, radius);
    }
    outColour = colour;
}
]];

--[[!
@fqxn OpenGL.transform
@desc Maps a centered unit quad to a top-left-origin logical viewport. Rotation
    is in radians. Flip rotates about Y with perspective; it does not mirror UVs.
!]]
function OpenGL.transform(nX, nY, nWidth, nHeight, nAngle, nFlip, nViewWidth, nViewHeight)
    local nCos, nSin = math.cos(nAngle), math.sin(nAngle);
    local nFlipCos, nFlipSin = math.cos(nFlip), math.sin(nFlip);
    local nXScale, nYScale = 2 / nViewWidth, -2 / nViewHeight;
    local nQ = nFlipSin * nWidth / 1200;
    local nTX, nTY = nX * nXScale - 1, 1 + nY * nYScale;
    return {
        nCos * nFlipCos * nWidth * nXScale + nTX * nQ,
        nSin * nFlipCos * nWidth * nYScale + nTY * nQ, 0, nQ,
        -nSin * nHeight * nXScale, nCos * nHeight * nYScale, 0, 0,
        0, 0, 1, 0,
        nTX, nTY, 0, 1,
    };
end

return OpenGL;