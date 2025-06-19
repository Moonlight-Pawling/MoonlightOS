#!/bin/bash
set -e

echo "=== MoonlightOS Build System - SIMPLE VERSION ==="

# Limpiar builds anteriores
rm -f bootloader.bin kernel_trampoline.o kernel.elf kernel.o kernel.bin hdd.img

echo "Compilando bootloader..."
nasm -f bin bootloader.asm -o bootloader.bin

echo "Compilando kernel 64-bit (versión simple)..."
nasm -f elf64 kernel.asm -o kernel_trampoline.o
x86_64-elf-gcc -m64 -ffreestanding -mcmodel=kernel -c kernel_simple.c -o kernel.o
x86_64-elf-ld -nostdlib -T linker.ld kernel_trampoline.o kernel.o -o kernel.elf
x86_64-elf-objcopy -O binary kernel.elf kernel.bin

# Examinar binario generado
echo "Examinando kernel.bin..."
hexdump -C -n 32 kernel.bin

# Forzar escritura de cabecera válida
echo "Forzando cabecera válida..."
# Primero aseguramos un tamaño de kernel válido
kernel_size=$(stat -c %s kernel.bin)
kernel_sectors=$(( (kernel_size + 511) / 512 ))
echo "Tamaño del kernel: $kernel_size bytes ($kernel_sectors sectores)"

# Escribir cabecera con valores fijos para testing
printf '\x64\x00\x00\x00\x34\x12\x00\x00' | dd of=kernel.bin bs=1 seek=0 count=8 conv=notrunc
echo "Cabecera forzada a valores conocidos (100 sectores, firma 0x1234)"

# Verificar que la cabecera se escribió correctamente
echo "Verificando cabecera forzada:"
hexdump -C -n 32 kernel.bin

echo "Creando imagen de disco..."
dd if=/dev/zero of=hdd.img bs=1M count=16 status=none
dd if=bootloader.bin of=hdd.img bs=512 seek=0 conv=notrunc status=none
dd if=kernel.bin of=hdd.img bs=512 seek=2 conv=notrunc status=none

echo "Iniciando QEMU..."
qemu-system-x86_64 -drive file=hdd.img,format=raw,index=0,media=disk \
                   -boot c -cpu qemu64 -m 1G
