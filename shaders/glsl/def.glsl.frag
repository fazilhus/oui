#version 460

layout (set = 2, binding = 0) uniform sampler2D tex_sampler;

layout (location = 0) in vec4 icol;
layout (location = 1) in vec2 iuv;

layout (location = 0) out vec4 ocol;

void main() {
	ocol = texture(tex_sampler, iuv) * icol;
}