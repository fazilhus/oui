package main

import "core:os"
import "core:log"

import "app"

main :: proc() {
	context.logger = log.create_console_logger()

	if ok, err := app.init("oui", 1280, 720, {}); !ok {
		app.deinit(err)
		os.exit(1)
	}
	defer app.deinit()

	app.run()
}

