package config

import "core:os/os2"
import fp "core:path/filepath"
import "core:log"

import ini "ext:odin-ini-parser"

Config :: struct {
	assets_path: string,
}

cfg: Config

read_config :: proc() -> bool {
	path: string
	err: os2.Error
	if path, err = os2.get_executable_path(context.temp_allocator); err != nil {
		log.errorf("could not get executable path: {}", err)
		return false
	}

	path = fp.dir(path)
	path = fp.join({path, "cfg.ini"})
	log.infof("config path: {}", path)

	bytes: []byte
	bytes, err = os2.read_entire_file_from_path(path, context.temp_allocator)
	if err != nil {
		log.errorf("could not read file %q", path)
		return false
	}

	ini_cfg, res := ini.parse(bytes)
	#partial switch res.err {
		case .IllegalToken: {
			log.errorf("illegal token in %q at %d:%d", path, res.pos.line+1, res.pos.col+1)
        }
        case .KeyWithoutEquals: {
        	log.errorf("key token found, but not assigned in %q at %d:%d", path, res.pos.line+1, res.pos.col+1)
        }
        case .ValueWithoutKey: {
        	log.errorf("value token found, but not preceeded by a key token in %q at %d:%d", path, res.pos.line+1, res.pos.col+1)
        }
        case .UnexpectedEquals: {
        	log.errorf("equals sign found in an unexpected location in %q at %d:%d", path, res.pos.line+1, res.pos.col+1)
		}
	}

	cfg.assets_path = ini_cfg["config"]["assets"]
	log_config()

	return true
}

log_config :: proc() {
	log.infof("assets path: %s", cfg.assets_path)
}