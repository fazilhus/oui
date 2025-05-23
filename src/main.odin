package main

import "base:runtime"

import "core:log"
import "core:os"
import "core:mem"
import "core:math/linalg"

import sdl "vendor:sdl3"
import stbi "vendor:stb/image"

default_ctx : runtime.Context

vshader_src := #load("../assets/shaders/spv/def.vert")
fshader_src := #load("../assets/shaders/spv/def.frag")

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
	uv: Vec2,
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
	defer sdl.Quit()
	log.infof("Initialized SDL3")

	win_size: [2]i32 = {1280, 720}
	win := sdl.CreateWindow("OUI", win_size.x, win_size.y, {})
	if win == nil {
		log.errorf("Failed to create window: %s", sdl.GetError)
		os.exit(1)
	}
	defer sdl.DestroyWindow(win)
	log.infof("Created a window %ix%i", win_size.x, win_size.y)

	gpu := sdl.CreateGPUDevice({.SPIRV}, true, nil)
	if gpu == nil {
		log.errorf("Failed to create gpu device: %s", sdl.GetError())
		os.exit(1)
	}
	defer sdl.DestroyGPUDevice(gpu)
	log.infof("Created a gpu device {}", sdl.GetGPUDeviceDriver(gpu))

	if ok := sdl.ClaimWindowForGPUDevice(gpu, win); !ok {
		log.errorf("Failed to claim gpu device to window: %s", sdl.GetError())
		os.exit(1)
	}
	defer sdl.ReleaseWindowFromGPUDevice(gpu, win)

	depth_tex := sdl.CreateGPUTexture(gpu, {
			type = .D2,
			format = .D24_UNORM,
			usage = {.DEPTH_STENCIL_TARGET},
			width = u32(win_size.x),
			height = u32(win_size.y),
			layer_count_or_depth = 1,
			num_levels = 1,
			sample_count = ._1,
			props = 0,
	})
	if depth_tex == nil {
		log.errorf("Failed to create gpu depth texture: %s", sdl.GetError())
		os.exit(1)
	}
	defer sdl.ReleaseGPUTexture(gpu, depth_tex)

	verticies := []Vertex_Data {
		{pos = {-0.5,  0.5, 0.0}, col = {1.0, 1.0, 0.0, 1.0}, uv = {0.0, 0.0}},
		{pos = { 0.5,  0.5, 0.0}, col = {0.0, 1.0, 1.0, 1.0}, uv = {1.0, 0.0}},
		{pos = {-0.5, -0.5, 0.0}, col = {1.0, 0.0, 1.0, 1.0}, uv = {0.0, 1.0}},
		{pos = { 0.5, -0.5, 0.0}, col = {1.0, 1.0, 1.0, 1.0}, uv = {1.0, 1.0}},
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
	if vbuf == nil {
		log.errorf("Failed to create gpu buffer: %s", sdl.GetError())
		os.exit(1)
	}
	defer sdl.ReleaseGPUBuffer(gpu, vbuf)

	ibuf := sdl.CreateGPUBuffer(gpu, {
		usage = {.INDEX},
		size = u32(indices_size),
		props = 0,
	})
	if ibuf == nil {
		log.errorf("Failed to create gpu buffer: %s", sdl.GetError())
		os.exit(1)
	}
	defer sdl.ReleaseGPUBuffer(gpu, ibuf)

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
		{
			location = 2,
			format = .FLOAT2,
			offset = u32(offset_of(Vertex_Data, uv)),
		},
	}

	img_size : [2]i32
	img_path : cstring = "./assets/textures/cobblestone_1.png"
	ch : i32 = 0
	img_data := stbi.load(img_path, &img_size.x, &img_size.y, &ch, 4)
	if img_data == nil {
		log.errorf("Failed to load texture: %s", stbi.failure_reason())
		os.exit(1)
	}
	defer stbi.image_free(img_data)
	log.infof("Loaded texture: %s (%i)", img_path, ch)

	img_data_size := img_size.x * img_size.y * ch

	tex := sdl.CreateGPUTexture(
		gpu,
		{
			type = .D2,
			format = .R8G8B8A8_UNORM,
			usage = {.SAMPLER},
			width = u32(img_size.x),
			height = u32(img_size.y),
			layer_count_or_depth = 1,
			num_levels = 1,
			sample_count = ._1,
			props = 0,
		},
	)
	if tex == nil {
		log.errorf("Failed to create gpu texture: %s", sdl.GetError())
		os.exit(1)
	}
	defer sdl.ReleaseGPUTexture(gpu, tex)

	tbuf := sdl.CreateGPUTransferBuffer(gpu, sdl.GPUTransferBufferCreateInfo {
		usage = .UPLOAD,
		size = u32(verticies_size + indices_size),
		props = 0,
	})

	tmem := cast([^]byte)sdl.MapGPUTransferBuffer(gpu, tbuf, false)
	mem.copy(tmem, raw_data(verticies), verticies_size)
	mem.copy(tmem[verticies_size:], raw_data(indices), indices_size)
	sdl.UnmapGPUTransferBuffer(gpu, tbuf)

	tex_tbuf := sdl.CreateGPUTransferBuffer(gpu, sdl.GPUTransferBufferCreateInfo {
		usage = .UPLOAD,
		size = u32(img_data_size),
		props = 0,
	})

	tex_tmem := cast([^]byte)sdl.MapGPUTransferBuffer(gpu, tex_tbuf, false)
	mem.copy(tex_tmem, img_data, int(img_data_size))
	sdl.UnmapGPUTransferBuffer(gpu, tex_tbuf)

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
	sdl.UploadToGPUTexture(
		copy_pass,
		{
			transfer_buffer = tex_tbuf,
			offset = 0,
		},
		{
			texture = tex,
			mip_level = 0,
			layer = 0,
			x = 0,
			y = 0,
			z = 0,
			w = u32(img_size.x),
			h = u32(img_size.y),
			d = 1,
		},
		false,
	)
	sdl.EndGPUCopyPass(copy_pass)

	if ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf); !ok {
		log.errorf("Failed to submit gpu copy cmd buffer: %s", sdl.GetError())
		os.exit(1)
	}

	sdl.ReleaseGPUTransferBuffer(gpu, tbuf)
	sdl.ReleaseGPUTransferBuffer(gpu, tex_tbuf)

	sampler := sdl.CreateGPUSampler(gpu, {
		min_filter = .NEAREST,
		mag_filter = .NEAREST,
		mipmap_mode = .NEAREST,
		address_mode_u = .REPEAT,
		address_mode_v = .REPEAT,
		address_mode_w = .REPEAT,
		mip_lod_bias = 0.0,
		max_anisotropy = 0.0,
		compare_op = .INVALID,
		min_lod = 0.0,
		max_lod = 0.0,
		enable_anisotropy = false,
		enable_compare = false,
	})
	if sampler == nil {
		log.errorf("Failed to create gpu sampler: %s", sdl.GetError())
		os.exit(1)
	}
	defer sdl.ReleaseGPUSampler(gpu, sampler)

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
	if vshader == nil {
		log.errorf("Failed to create gpu shader: %s", sdl.GetError())
		os.exit(1)
	}
	defer sdl.ReleaseGPUShader(gpu, vshader)

	fshader := sdl.CreateGPUShader(gpu, {
		code_size = len(fshader_src),
		code = raw_data(fshader_src),
		entrypoint = "main",
		format = {.SPIRV},
		stage = .FRAGMENT,
		num_samplers = 1,
		num_storage_textures = 0,
		num_storage_buffers = 0,
		num_uniform_buffers = 0,
	})
	if fshader == nil {
		log.errorf("Failed to create gpu shader: %s", sdl.GetError())
		os.exit(1)
	}
	defer sdl.ReleaseGPUShader(gpu, fshader)

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
		depth_stencil_state = {
			compare_op = .LESS,
			enable_depth_test = true,
			enable_depth_write = true,
		},
		target_info = {
			color_target_descriptions = &(sdl.GPUColorTargetDescription {
				format = sdl.GetGPUSwapchainTextureFormat(gpu, win),
			}),
			num_color_targets = 1,
			depth_stencil_format = .D24_UNORM,
			has_depth_stencil_target = true,
		},
		props = 0,
	})
	if def_pipeline == nil {
		log.errorf("Failed to create gpu pipeline: %s", sdl.GetError())
		os.exit(1)
	}
	defer sdl.ReleaseGPUGraphicsPipeline(gpu, def_pipeline)

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
		model_mat = linalg.matrix4_translate_f32({0, 0, -3.0}) * linalg.matrix4_rotate_f32(rotation, {0, 1, 0})
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
		depth_target := sdl.GPUDepthStencilTargetInfo {
			texture = depth_tex,
			clear_depth = 1,
			load_op = .CLEAR,
			store_op = .DONT_CARE,
		}
		render_pass := sdl.BeginGPURenderPass(
			cmd_buf,
			&color_target,
			1,
			&depth_target,
		)

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
		sdl.BindGPUFragmentSamplers(render_pass, 0, &(sdl.GPUTextureSamplerBinding {
			texture = tex,
			sampler = sampler,
		}), 1)

		sdl.DrawGPUIndexedPrimitives(render_pass, u32(len(indices)), 1, 0, 0, 0)

		ubo1 : UBO
		ubo1.mvp = proj_mat * linalg.matrix4_translate_f32({0, 0, -5.0})

		sdl.PushGPUVertexUniformData(cmd_buf, 0, &ubo1, size_of(ubo1))

		sdl.DrawGPUIndexedPrimitives(render_pass, u32(len(indices)), 1, 0, 0, 0)

		sdl.EndGPURenderPass(render_pass)

		if ok := sdl.SubmitGPUCommandBuffer(cmd_buf); !ok {
			log.errorf("Failed to submit gpu cmd buffer: %s", sdl.GetError())
			break main_loop
		}
	}
}