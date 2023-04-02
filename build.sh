#!/usr/bin/bash

# shell script might be ran on windows through
# msys or cygwin, but exe extension is needed
# to use tools like remedybg
case "$OSTYPE" in
  msys*)    extension=exe ;;
  cygwin*)  extension=exe ;;
  *)        extension=out;;
esac

# odin build src "-out=icon_composer.$extension" -o:none -debug
odin build src "-out=icon_composer.$extension" -o:speed -no-bounds-check
