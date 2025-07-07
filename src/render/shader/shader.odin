package shader

import "core:log"
import "core:os/os2"
import "core:path/filepath"
import "core:time"

Shader_ctx :: struct {
	path: string,
}

Shader_Source_Type :: enum {
	VERTEX,
	FRAGMENT,
}

shader_ctx: Shader_ctx

shader_sources: map[string]time.Time

Shader_Binary :: struct {
	name: string,
	vert: []u8,
	frag: []u8,
}

init :: proc(shader_path: string) {
	assert(os2.is_dir(shader_path))

	shader_ctx.path = shader_path
	shader_sources = make(map[string]time.Time)
}

deinit :: proc() {
	delete(shader_sources)
}

register_shaders :: proc() {
	assert(os2.is_directory(shader_ctx.path))

	fd, open_err := os2.open(shader_ctx.path)
	if open_err != nil {
		log.errorf("Could not open %s: %s", shader_ctx.path, open_err)
	}

	files, read_err := os2.read_dir(fd, 0, context.temp_allocator)
	if read_err != nil {
		log.errorf("Could not read %s: %s", shader_ctx.path, read_err)
		return
	}

	for file in files {
		name := filepath.short_stem(file.name)
		time, err := os2.modification_time_by_path(file.fullpath)
		if err != nil {
			log.errorf("Could not get file last write time %s: %s", file.fullpath, err)
			continue
		}

		if name in shader_sources {
			if time._nsec > shader_sources[name]._nsec {
				shader_sources[name] = time
			}
		} else {
			shader_sources[name] = time
		}
		log.infof("Registered shader source: %s, last write time: %i", file.name, time)
	}

	for it in shader_sources {
		log.infof("Registered shader: %s %i", it, shader_sources[it])
	}
}
