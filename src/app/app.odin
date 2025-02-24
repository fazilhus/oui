package app

import "core:log"

import sdl "vendor:sdl3"
import gl "vendor:OpenGL"

@(private)
Context : struct {
    win : ^sdl.Window,
    ctx : sdl.GLContext,

    should_close : bool,

    frame_start:   f64,
	frame_end:     f64,
	frame_elapsed: f64,
}

@(private)
ctx := Context

App_Error :: enum {
    NONE,
    SDL_INIT,
    WINDOW_INIT,
    RENDERER_INIT,
}

init :: proc(name: cstring, width, height: i32, flags: sdl.WindowFlags) -> (ok : bool, err : App_Error) {

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
    
    ctx.win = sdl.CreateWindow(name, width, height, flags + {.OPENGL, .HIDDEN, .RESIZABLE})
    if ctx.win == nil {
        log.errorf("[ERROR] SDL3 failed to create window: %s\n", sdl.GetError())
        return false, .WINDOW_INIT
    }

    ctx.ctx = sdl.GL_CreateContext(ctx.win)
    if ctx.ctx == nil {
        log.errorf("[ERROR] SDL3 failed to create OpenGL context: %s\n", sdl.GetError())
        return false, .RENDERER_INIT
    }

    sdl.GL_MakeCurrent(ctx.win, ctx.ctx)
    sdl.GL_SetSwapInterval(1)
    sdl.ShowWindow(ctx.win)

    return true, .NONE
}

deinit :: proc(err: App_Error = .NONE) {
    #partial switch err {
    case .WINDOW_INIT:
        defer sdl.Quit()
        fallthrough
    case .RENDERER_INIT:
        defer sdl.DestroyWindow(ctx.win)
        fallthrough
    case .NONE:
        defer sdl.GL_DestroyContext(ctx.ctx)
    }
}

handle_events :: proc() {
    e : sdl.Event
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

update :: proc(dt: f64) {
    // gl.Viewport(0, 0, 1280, 720)
    gl.ClearColor(25, 25, 25, 255)
    gl.Clear(gl.COLOR_BUFFER_BIT)

    sdl.GL_SwapWindow(ctx.win)
}

draw :: proc() {
    
}

run :: proc() {
    ctx.should_close = false
    ctx.frame_elapsed = 0.001

    for !ctx.should_close {
        handle_events()
        update(ctx.frame_elapsed)
        draw()

        ctx.frame_end     = f64(sdl.GetPerformanceCounter()) / f64(sdl.GetPerformanceFrequency())
		ctx.frame_elapsed = ctx.frame_end - ctx.frame_start
		ctx.frame_start   = ctx.frame_end
    }
}