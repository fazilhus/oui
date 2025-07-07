package shader

import "core:log"
import "core:os/os2"
import fp "core:path/filepath"
import "core:time"

Shader_ctx :: struct {
	glsl_path: string,
	spv_path: string,
}

Shader_Source_Type :: enum {
	VERTEX,
	FRAGMENT,
}

shader_ctx: Shader_ctx

@(private)
glsl_shader_sources: map[string]time.Time

shader_sources: []string = nil

Shader_Binary :: struct {
	name: string,
	vert: []u8,
	frag: []u8,
}

init :: proc(cfg_path: string) {
	path := fp.join({cfg_path, "shaders\\glsl"})
	if !os2.is_directory(path) {
		log.errorf("no path to glsl shaders found (%s)", path)
		return
	}
	shader_ctx.glsl_path = path
	glsl_shader_sources = make(map[string]time.Time)

	path = fp.join({cfg_path, "shaders\\spv"})
	if !os2.is_directory(path) {
		log.errorf("no path to spv shaders found (%s)", path)
		return
	}
	shader_ctx.spv_path = path
}

deinit :: proc() {
	delete(glsl_shader_sources)
	if shader_sources != nil {
		delete(shader_sources)
	}
}

register_shaders :: proc() {
	fd, open_err := os2.open(shader_ctx.glsl_path)
	if open_err != nil {
		log.errorf("Could not open %s: %s", shader_ctx.glsl_path, open_err)
	}

	files, read_err := os2.read_directory(fd, 0, context.temp_allocator)
	if read_err != nil {
		log.errorf("Could not read %s: %s", shader_ctx.glsl_path, read_err)
		return
	}

	for file in files {
		name := fp.short_stem(file.name)
		time, err := os2.modification_time_by_path(file.fullpath)
		if err != nil {
			log.errorf("Could not get file last write time %s: %s", file.fullpath, err)
			continue
		}

		if name in glsl_shader_sources {
			if time._nsec > glsl_shader_sources[name]._nsec {
				glsl_shader_sources[name] = time
			}
		} else {
			glsl_shader_sources[name] = time
		}
		log.infof("Registered shader source: %s, last write time: %i", file.name, time)
	}

	for it in glsl_shader_sources {
		log.infof("Registered shader: %s %i", it, glsl_shader_sources[it])
	}
}
