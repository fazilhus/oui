package main

import "base:runtime"

import "core:log"
import "core:os"
import "core:mem"
import "core:math/linalg"

import sdl "vendor:sdl3"

default_ctx : runtime.Context

vshader_src := #load("../shaders/spv/def.spv.vert")
fshader_src := #load("../shaders/spv/def.spv.frag")

UBO :: struct {
	mvp : matrix[4,4]f32,
}

Vec1 :: [1]f32
Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

Vertex_Data :: struct #align(4) {
	pos: Vec3,
	col: Vec4,
}

main :: proc() {
	context.logger = log.create_console_logger()
	default_ctx = context

	sdl.SetLogPriorities(.VERBOSE)
	sdl.SetLogOutputFunction(proc "c" (userdata: rawptr, category: sdl.LogCategory, priority: sdl.LogPriority, message: cstring) {
		context = default_ctx
		#partial switch priority {
			case .DEBUG: log.debug(message)
			case .INFO: log.info(message)
			case .WARN: log.warn(message)
			case .ERROR: log.error(message)
			case .CRITICAL: log.panic(message)
		}
	}, nil)

	if ok := sdl.Init({.VIDEO}); !ok {
		log.errorf("Failed to init sdl: %s", sdl.GetError())
		os.exit(1)
	}
	log.infof("Initialized SDL3")

	win := sdl.CreateWindow("OUI", 1280, 720, {})
	if win == nil {
		log.errorf("Failed to create window: %s", sdl.GetError)
		sdl.Quit()
		os.exit(1)
	}
	log.infof("Created a window %ix%i", 1280, 720)

	gpu := sdl.CreateGPUDevice({.SPIRV}, true, nil)
	if gpu == nil {
		log.errorf("Failed to create gpu device: %s", sdl.GetError())
		sdl.DestroyWindow(win)
		sdl.Quit()
		os.exit(1)
	}
	log.infof("Created a gpu device {}", sdl.GetGPUDeviceDriver(gpu))

	if ok := sdl.ClaimWindowForGPUDevice(gpu, win); !ok {
		log.errorf("Failed to claim gpu device to window: %s", sdl.GetError())
		sdl.DestroyGPUDevice(gpu)
		sdl.DestroyWindow(win)
		sdl.Quit()
		os.exit(1)
	}

	verticies := []Vertex_Data {
		{pos = {-0.5,  0.5, 0.0}, col = {1.0, 1.0, 0.0, 1.0}},
		{pos = { 0.5,  0.5, 0.0}, col = {0.0, 1.0, 1.0, 1.0}},
		{pos = {-0.5, -0.5, 0.0}, col = {1.0, 0.0, 1.0, 1.0}},
		{pos = { 0.5, -0.5, 0.0}, col = {1.0, 1.0, 1.0, 1.0}},
	}
	verticies_size := len(verticies) * size_of(verticies[0])

	indices := []u16 {
		0, 1, 2,
		2, 1, 3,
	}
	indices_size := len(indices) * size_of(indices[0])

	vertex_buffer_descs := []sdl.GPUVertexBufferDescription {
		{
			slot = 0,
			pitch = size_of(Vertex_Data),
			input_rate = .VERTEX,
		},
	}

	vbuf := sdl.CreateGPUBuffer(gpu, {
		usage = {.VERTEX},
		size = u32(verticies_size),
		props = 0,
	})

	ibuf := sdl.CreateGPUBuffer(gpu, {
		usage = {.INDEX},
		size = u32(indices_size),
		props = 0,
	})

	vertex_attribs := []sdl.GPUVertexAttribute {
		{
			location = 0,
			format = .FLOAT3,
			offset = u32(offset_of(Vertex_Data, pos)),
		},
		{
			location = 1,
			format = .FLOAT4,
			offset = u32(offset_of(Vertex_Data, col)),
		},
	}

	tbuf := sdl.CreateGPUTransferBuffer(gpu, sdl.GPUTransferBufferCreateInfo {
		usage = .UPLOAD,
		size = u32(verticies_size + indices_size),
		props = 0,
	})

	tmem := cast([^]byte)sdl.MapGPUTransferBuffer(gpu, tbuf, false)
	mem.copy(tmem, raw_data(verticies), verticies_size)
	mem.copy(tmem[verticies_size:], raw_data(indices), indices_size)
	sdl.UnmapGPUTransferBuffer(gpu, tbuf)

	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
	sdl.UploadToGPUBuffer(
		copy_pass,
		{
			transfer_buffer = tbuf,
			offset = 0,
		},
		{
			buffer = vbuf,
			offset = 0,
			size = u32(verticies_size),
		},
		false,
	)
	sdl.UploadToGPUBuffer(
		copy_pass,
		{
			transfer_buffer = tbuf,
			offset = u32(verticies_size),
		},
		{
			buffer = ibuf,
			size = u32(indices_size),
		},
		false,
	)
	sdl.EndGPUCopyPass(copy_pass)

	if ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf); !ok {
		log.errorf("Failed to submit gpu copy cmd buffer: %s", sdl.GetError())
		sdl.ReleaseWindowFromGPUDevice(gpu, win)
		sdl.DestroyGPUDevice(gpu)
		sdl.DestroyWindow(win)
		sdl.Quit()
		os.exit(1)
	}

	sdl.ReleaseGPUTransferBuffer(gpu, tbuf)

	vshader := sdl.CreateGPUShader(gpu, {
		code_size = len(vshader_src),
		code = raw_data(vshader_src),
		entrypoint = "main",
		format = {.SPIRV},
		stage = .VERTEX,
		num_samplers = 0,
		num_storage_textures = 0,
		num_storage_buffers = 0,
		num_uniform_buffers = 1,
	})

	fshader := sdl.CreateGPUShader(gpu, {
		code_size = len(fshader_src),
		code = raw_data(fshader_src),
		entrypoint = "main",
		format = {.SPIRV},
		stage = .FRAGMENT,
		num_samplers = 0,
		num_storage_textures = 0,
		num_storage_buffers = 0,
		num_uniform_buffers = 0,
	})

	def_pipeline := sdl.CreateGPUGraphicsPipeline(gpu, {
		vertex_shader = vshader,
		fragment_shader = fshader,
		vertex_input_state = {
			vertex_buffer_descriptions = raw_data(vertex_buffer_descs),
			num_vertex_buffers = u32(len(vertex_buffer_descs)),
			vertex_attributes = raw_data(vertex_attribs),
			num_vertex_attributes = u32(len(vertex_attribs)),
		},
		primitive_type = .TRIANGLELIST,
		target_info = {
			color_target_descriptions = &(sdl.GPUColorTargetDescription {
				format = sdl.GetGPUSwapchainTextureFormat(gpu, win),
			}),
			num_color_targets = 1,
		},
	})
	sdl.ReleaseGPUShader(gpu, vshader)
	sdl.ReleaseGPUShader(gpu, fshader)

	rotation_speed := linalg.to_radians(f32(90))
	rotation : f32 = 0

	proj_mat := linalg.matrix4_perspective_f32(0.5, 1280.0 / 720.0, 0.01, 100, true)
	model_mat := linalg.matrix4_translate_f32({0, 0, -5}) * linalg.matrix4_rotate_f32(rotation, {0, 1, 0})

	ubo := UBO {
		mvp = proj_mat * model_mat,
	}

	last_frame := sdl.GetTicks()
	new_frame := last_frame
	dt : f32 = 0

	main_loop: for {
		// event handling
		e : sdl.Event
		event_loop: for sdl.PollEvent(&e) {
			#partial switch e.type {
				case .QUIT:
					break main_loop
				case .KEY_DOWN:
					#partial switch e.key.scancode {
						case .ESCAPE:
							break main_loop
					}
			}
		}

		// update game state
		last_frame = new_frame
		new_frame = sdl.GetTicks()
		dt = f32(new_frame - last_frame) / 1000.0

		rotation += dt * rotation_speed
		if rotation > 360.0 do rotation = 0.0
		model_mat = linalg.matrix4_translate_f32({0, 0, -5}) * linalg.matrix4_rotate_f32(rotation, {0, 1, 0})
		ubo.mvp = proj_mat * model_mat

		// render
		cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
		swapchain_tex: ^sdl.GPUTexture
		if ok := sdl.WaitAndAcquireGPUSwapchainTexture(cmd_buf, win, &swapchain_tex, nil, nil); !ok {
			log.errorf("Failed to aquire gpu swapchain tex: %s", sdl.GetError())
			break main_loop
		}

		if swapchain_tex == nil do continue

		color_target := sdl.GPUColorTargetInfo {
			texture = swapchain_tex,
			clear_color = {0.2, 0.2, 0.2, 1.0},
			load_op = .CLEAR,
			store_op = .STORE,
		}
		render_pass := sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, nil)

		sdl.BindGPUGraphicsPipeline(render_pass, def_pipeline)
		sdl.BindGPUVertexBuffers(
			render_pass,
			0, 
			&(sdl.GPUBufferBinding {
				buffer = vbuf,
				offset = 0,
			}),
			1,
		)
		sdl.BindGPUIndexBuffer(
			render_pass,
			{
				buffer = ibuf,
				offset = 0,
			},
			._16BIT,
		)
		sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo, size_of(ubo))

		sdl.DrawGPUIndexedPrimitives(render_pass, u32(len(indices)), 1, 0, 0, 0)

		sdl.EndGPURenderPass(render_pass)

		if ok := sdl.SubmitGPUCommandBuffer(cmd_buf); !ok {
			log.errorf("Failed to submit gpu cmd buffer: %s", sdl.GetError())
			break main_loop
		}
	}

	sdl.ReleaseGPUBuffer(gpu, vbuf)
	sdl.ReleaseGPUBuffer(gpu, ibuf)
	sdl.ReleaseGPUGraphicsPipeline(gpu, def_pipeline)
	sdl.ReleaseWindowFromGPUDevice(gpu, win)
	sdl.DestroyGPUDevice(gpu)
	sdl.DestroyWindow(win)
	sdl.Quit()
}