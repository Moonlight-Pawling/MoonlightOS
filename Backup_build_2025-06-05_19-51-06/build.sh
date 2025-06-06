#!/bin/bash
set -e

read -p "¿Guardar copia de builds anteriores? (y/n): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    mkdir -p "Backup_build_$timestamp"
    cp bootloader.asm kernel.asm kernel.c linker.ld build.sh \
       "Backup_build_$timestamp/" 2>/dev/null || true
    cp bootloader.bin kernel_trampoline.o kernel.elf kernel.o \
       kernel.bin hdd.img "Backup_build_$timestamp/" 2>/dev/null || true
fi

# Limpiar builds anteriores
rm -f bootloader.bin kernel_trampoline.o kernel.elf kernel.o kernel.bin hdd.img

echo "Compilando kernel.asm (stub 16/32/64 bits) como ELF64..."
nasm -f elf64 -g kernel.asm -o kernel_trampoline.o

echo "Compilando kernel en C (modo largo)..."
x86_64-elf-gcc -ffreestanding -mno-red-zone -m64 -g -c kernel.c -o kernel.o

echo "Linkeando kernel completo con linker.ld..."
x86_64-elf-ld -nostdlib -T linker.ld kernel_trampoline.o kernel.o -o kernel.elf

echo "Generando kernel.bin plano..."
x86_64-elf-objcopy -O binary kernel.elf kernel.bin

KERNEL_SIZE=$(stat --format=%s kernel.bin)
KERNEL_SECTORS=$(( (KERNEL_SIZE + 511) / 512 ))
echo "Kernel: $KERNEL_SIZE bytes = $KERNEL_SECTORS sectores"

echo "Compilando bootloader (ASM, modo real) con KERNEL_SECTORS=$KERNEL_SECTORS..."
nasm -D KERNEL_SECTORS=$KERNEL_SECTORS -f bin bootloader.asm -o bootloader.bin

echo "Creando imagen de disco de 10MB..."
dd if=/dev/zero of=hdd.img bs=512 count=20480

echo "Escribiendo bootloader en hdd.img..."
dd if=bootloader.bin of=hdd.img bs=512 seek=0 conv=notrunc

echo "Escribiendo kernel.bin en sector 1..."
dd if=kernel.bin of=hdd.img bs=512 seek=1 conv=notrunc

echo "Iniciando QEMU desde hdd.img..."
qemu-system-x86_64 \
  -drive file=hdd.img,format=raw,if=ide,index=0,media=disk \
  -boot order=c \
  -no-reboot \
  -monitor stdio