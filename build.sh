#!/usr/bin/bash

# shell script might be ran on windows through
# msys or cygwin, but exe extension is needed
# to use tools like remedybg
case "$OSTYPE" in
  msys*)
    extension=exe
    flags=-subsystem:windows
    ;;
  cygwin*)
    extension=exe
    flags=-subsystem:windows
    ;;
  *)
    extension=out
    ;;
esac

# odin build src "-out=icon_composer.$extension" "$flags" -o:none -debug
odin build src "-out=icon_composer.$extension" "$flags" -o:speed -no-bounds-check
