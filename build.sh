#!/bin/sh
# Builds trayres.exe with zig (any host OS). No CRT: own entry point, system DLLs only.
set -eu
cd "$(dirname "$0")"
lib=$(zig env | sed -n 's/.*\.lib_dir = "\(.*\)",/\1/p')
zig cc -target x86_64-windows-gnu -Os -s -nostdlib -fno-stack-protector -mno-stack-arg-probe \
  -isystem "$lib/libc/include/any-windows-any" -Wall -Wextra -Werror \
  -Wl,--entry=start -Wl,--subsystem,windows \
  trayres.c res/trayres.rc -lkernel32 -luser32 -lshell32 -ladvapi32 \
  -o trayres.exe
rm -f trayres.pdb
ls -l trayres.exe
