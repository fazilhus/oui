package config

import "core:os/os2"
import fp "core:path/filepath"
import "core:log"

Config :: struct {
	assets_path: string,
}

cfg: Config

create_default_config :: proc() {
	cfg.assets_path = ".\\assets\\"
}

read_or_create_config :: proc() -> bool {
	path: string
	err: os2.Error
	if path, err = os2.get_executable_path(context.temp_allocator); err != nil {
		log.errorf("could not get executable path: {}", err)
		return false
	}

	path = fp.dir(path)
	log.infof("cwd: {}", path)

	
	
	return true
}