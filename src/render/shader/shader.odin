package shader

import "core:log"
import "core:os"
import "core:path/filepath"

Shader_ctx :: struct {
	path: string,
}

Shader_Source_Type :: enum {
	VERTEX,
	FRAGMENT,
}

shader_ctx: Shader_ctx

shader_sources: map[string]os.File_Time

Shader_Binary :: struct {
	name: string,
	vert: []u8,
	frag: []u8,
}

init :: proc(shader_path: string) {
	assert(os.is_dir(shader_path))

	shader_ctx.path = shader_path
	shader_sources = make(map[string]os.File_Time)
}

deinit :: proc() {
	delete(shader_sources)
}

register_shaders :: proc() {
	assert(os.is_dir(shader_ctx.path))

	fd, open_err := os.open(shader_ctx.path)
	if open_err != nil {
		log.errorf("Could not open %s: %s", shader_ctx.path, open_err)
	}

	files, read_err := os.read_dir(fd, 0)
	if read_err != nil {
		log.errorf("Could not read %s: %s", shader_ctx.path, read_err)
		return
	}

	for file in files {
		name := filepath.short_stem(file.name)
		time, err := os.last_write_time_by_name(file.fullpath)
		if err != nil {
			log.errorf("Could not get file last write time %s: %s", file.fullpath, err)
			continue
		}

		if name in shader_sources {
			if shader_sources[name] < time {
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
