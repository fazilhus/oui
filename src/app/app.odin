package app

import "core:log"

import glm "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import sdl "vendor:sdl3"

@(private)
Context: struct {
	win:           ^sdl.Window,
	width:         i32,
	height:        i32,
	ctx:           sdl.GLContext,
	should_close:  bool,
	frame_start:   f64,
	frame_end:     f64,
	frame_elapsed: f64,
	program:       u32,
	uniforms:      gl.Uniforms,
	vao:           u32,
	vbo:           u32,
	ebo:           u32,
	indices:       []u32,
}

@(private)
ctx := Context

@(private)
Vertex :: struct {
	pos: glm.vec3,
	col: glm.vec4,
}

@(private)
Rect :: struct {
	pos:  glm.vec2,
	size: glm.vec2,
	r:    f32,
}

@(private)
rect := Rect{}

@(private)
vert_src := `#version 460 core

layout(location=0) in vec3 a_position;
layout(location=1) in vec4 a_color;

layout(location=0) out vec4 o_color;
layout(location=1) out vec4 o_dims;
layout(location=2) out float o_r;

uniform mat4 u_transform;
uniform vec4 u_dims;
uniform float u_r;

void main() {
	gl_Position = u_transform * vec4(a_position, 1.0);
	o_color = a_color;
}
`


@(private)
frag_src := `#version 460 core

layout(location=0) in vec4 i_color;
layout(location=1) in vec4 o_dims;
layout(location=2) in float o_r;

out vec4 o_color;

bool in_rect() {

}

void main() {
	o_color = i_color;
}
`


App_Error :: enum {
	NONE,
	SDL_INIT,
	WINDOW_INIT,
	RENDERER_INIT,
	SHADER_COMPILE,
}

init :: proc(
	name: cstring,
	width, height: i32,
	flags: sdl.WindowFlags,
) -> (
	ok: bool,
	err: App_Error,
) {

	if res := sdl.Init({.VIDEO}); !res {
		log.errorf("[ERROR] SDL3 failed to init: %s\n", sdl.GetError())
		return false, .SDL_INIT
	}

	sdl.GL_SetAttribute(.CONTEXT_FLAGS, 0)
	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl.GL_CONTEXT_PROFILE_CORE))
	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 4)
	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 6)

	sdl.GL_SetAttribute(.DOUBLEBUFFER, 1)
	sdl.GL_SetAttribute(.DEPTH_SIZE, 24)
	sdl.GL_SetAttribute(.STENCIL_SIZE, 8)

	ctx.width = width
	ctx.height = height

	ctx.win = sdl.CreateWindow(name, ctx.width, ctx.height, flags + {.OPENGL, .HIDDEN, .RESIZABLE})
	if ctx.win == nil {
		log.errorf("[ERROR] SDL3 failed to create window: %s\n", sdl.GetError())
		return false, .WINDOW_INIT
	}

	ctx.ctx = sdl.GL_CreateContext(ctx.win)
	if ctx.ctx == nil {
		log.errorf("[ERROR] SDL3 failed to create OpenGL context: %s\n", sdl.GetError())
		return false, .RENDERER_INIT
	}

	gl.load_up_to(4, 6, sdl.gl_set_proc_address)

	if program, program_ok := gl.load_shaders_source(vert_src, frag_src); !program_ok {
		log.errorf("OpenGL failed to compile GLSL program: %v\n", gl.GetError())
		return false, .SHADER_COMPILE
	} else {
		ctx.program = program
	}

	gl.UseProgram(ctx.program)

	ctx.uniforms = gl.get_uniforms_from_program(ctx.program)

	gl.GenVertexArrays(1, &ctx.vao)
	gl.BindVertexArray(ctx.vao)

	gl.GenBuffers(1, &ctx.vbo)
	gl.GenBuffers(1, &ctx.ebo)

	vertices := []Vertex {
		{{-1.0, +1.0, 0}, {1.0, 0.0, 0.0, 1.0}},
		{{-1.0, -1.0, 0}, {1.0, 1.0, 0.0, 1.0}},
		{{+1.0, -1.0, 0}, {0.0, 1.0, 0.0, 1.0}},
		{{+1.0, +1.0, 0}, {0.0, 0.0, 1.0, 1.0}},
	}

	ctx.indices = []u32{0, 1, 2, 2, 3, 0}

	gl.BindBuffer(gl.ARRAY_BUFFER, ctx.vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(vertices[0]),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)
	gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
	gl.VertexAttribPointer(1, 4, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, col))

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ctx.ebo)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(ctx.indices) * size_of(ctx.indices[0]),
		raw_data(ctx.indices),
		gl.STATIC_DRAW,
	)

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)


	sdl.GL_MakeCurrent(ctx.win, ctx.ctx)
	sdl.GL_SetSwapInterval(1)
	sdl.ShowWindow(ctx.win)

	return true, .NONE
}

deinit :: proc(err: App_Error = .NONE) {
	#partial switch err {
	case .NONE:
		{
			gl.DeleteBuffers(1, &ctx.vbo)
			gl.DeleteBuffers(1, &ctx.ebo)
			gl.DeleteVertexArrays(1, &ctx.vao)
			delete(ctx.uniforms)
			gl.DeleteProgram(ctx.program)
			sdl.GL_DestroyContext(ctx.ctx)
			sdl.DestroyWindow(ctx.win)
			sdl.Quit()
		}
	case .SDL_INIT:
		{}
	case .WINDOW_INIT:
		{
			sdl.Quit()
		}
	case .RENDERER_INIT:
		{
			sdl.DestroyWindow(ctx.win)
			sdl.Quit()
		}
	case .SHADER_COMPILE:
		{
			sdl.GL_DestroyContext(ctx.ctx)
			sdl.DestroyWindow(ctx.win)
			sdl.Quit()
		}
	}
}

handle_events :: proc() {
	e: sdl.Event
	for sdl.PollEvent(&e) {
		#partial switch e.type {
		case .QUIT:
			ctx.should_close = true
		case .KEY_DOWN:
			#partial switch e.key.scancode {
			case .ESCAPE:
				ctx.should_close = true
			}
		case .WINDOW_RESIZED:
			// TODO
			fallthrough
		}
	}
}

update :: proc(dt: f64) {}

draw :: proc() {
	model := glm.mat4{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}

	gl.UseProgram(ctx.program)

	gl.UniformMatrix4fv(ctx.uniforms["u_transform"].location, 1, false, &model[0, 0])

	gl.Viewport(0, 0, ctx.width, ctx.height)
	gl.ClearColor(25, 25, 25, 255)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	gl.BindVertexArray(ctx.vao)
	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)

	gl.DrawElements(gl.TRIANGLES, i32(len(ctx.indices)), gl.UNSIGNED_INT, nil)

	gl.BindVertexArray(0)

	sdl.GL_SwapWindow(ctx.win)

}

run :: proc() {
	ctx.should_close = false
	ctx.frame_elapsed = 0.001

	for !ctx.should_close {
		handle_events()
		update(ctx.frame_elapsed)
		draw()

		ctx.frame_end = f64(sdl.GetPerformanceCounter()) / f64(sdl.GetPerformanceFrequency())
		ctx.frame_elapsed = ctx.frame_end - ctx.frame_start
		ctx.frame_start = ctx.frame_end
	}
}
