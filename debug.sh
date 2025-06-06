#!/bin/bash

# Ejecutar build.sh primero (sin iniciar QEMU al final)
./build.sh norun

# Iniciar QEMU con soporte de GDB
qemu-system-x86_64 -drive format=raw,file=hdd.img -s -S &

# Conectar GDB al puerto de depuración de QEMU
gdb -ex "target remote localhost:1234" \
    -ex "symbol-file kernel.elf" \
    -ex "break start16" \
    -ex "break start32" \
    -ex "break start64" \
    -ex "break kernel_main" \
    -ex "continue"
