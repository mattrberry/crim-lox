# Package

version       = "0.1.0"
author        = "Matthew Berry"
description   = "A Nim implementation of clox from Crafting Interpreters"
license       = "MIT"
srcDir        = "src"
bin           = @["nlox"]


# Dependencies

requires "nim >= 1.6.0"

task test, "test":
  exec "nim c -r tests/runner.nim"
