package main

import "core:os"

import "app"

main :: proc() {
    if ok, err := app.init("oui", 1280, 720, {}); !ok {
        app.deinit(err)
        os.exit(1)
    }
    defer app.deinit()

    app.run()
}