#version 460

layout (location = 0) in vec4 icol;

layout (location = 0) out vec4 ocol;

void main() {
	ocol = icol;
}