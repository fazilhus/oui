package shaderc

Target_Env :: enum {
	Vulkan,
	OpenGL,
	OpenGL_Compat,
	WebGPU,
	Default = Vulkan,
}

Env_Version :: enum {
	Vulkan_1_0 = 1 << 22,
	Vulkan_1_1 = (1 << 22) | (1 << 12),
  	Vulkan_1_2 = (1 << 22) | (2 << 12),
  	Vulkan_1_3 = (1 << 22) | (3 << 12),
  	Vulkan_1_4 = (1 << 22) | (4 << 12),
  	OpenGL_4_5 = 450,
  	WebGPU,
}

SPIRV_Version :: enum {
	SPIRV_Version_1_0 = 0x010000,
  	SPIRV_Version_1_1 = 0x010100,
  	SPIRV_Version_1_2 = 0x010200,
  	SPIRV_Version_1_3 = 0x010300,
  	SPIRV_Version_1_4 = 0x010400,
  	SPIRV_Version_1_5 = 0x010500,
  	SPIRV_Version_1_6 = 0x010600
}