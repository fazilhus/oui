#version 460

layout (set = 1, binding = 0) uniform ubo {
	mat4 mvp;
};

layout (location = 0) in vec3 ipos;
layout (location = 1) in vec4 icol;
layout (location = 2) in vec2 iuv;

layout (location = 0) out vec4 ocol;
layout (location = 1) out vec2 ouv;

void main() {
	gl_Position = mvp * vec4(ipos, 1);
	ocol = icol;
	ouv = iuv;
}