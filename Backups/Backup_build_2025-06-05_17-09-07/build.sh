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

# 1) Limpiar builds anteriores
rm -f bootloader.bin kernel_trampoline.o kernel.elf kernel.o kernel.bin hdd.img

# 2) Compilar kernel.asm (stub 16→32→64 bits) como ELF64
echo "Compilando kernel.asm (stub 16/32/64 bits) como ELF64..."
nasm -f elf64 kernel.asm -o kernel_trampoline.o

# 3) Compilar kernel.c (modo largo, C)
echo "Compilando kernel en C (modo largo)..."
x86_64-elf-gcc -ffreestanding -mno-red-zone -m64 -c kernel.c -o kernel.o

# 4) Linkear ambos en un solo ELf
echo "Linkeando kernel completo con linker.ld..."
x86_64-elf-ld -nostdlib -T linker.ld kernel_trampoline.o kernel.o -o kernel.elf

# 5) Convertir a binario plano
echo "Generando kernel.bin plano..."
x86_64-elf-objcopy -O binary kernel.elf kernel.bin

# 6) Calcular número de sectores que ocupa kernel.bin
KERNEL_SIZE=$(stat --format=%s kernel.bin)
KERNEL_SECTORS=$(( (KERNEL_SIZE + 511) / 512 ))
echo "Kernel: $KERNEL_SIZE bytes = $KERNEL_SECTORS sectores"

# 7) Compilar bootloader usando -D para definir KERNEL_SECTORS
echo "Compilando bootloader (ASM, modo real) con KERNEL_SECTORS=$KERNEL_SECTORS..."
nasm -D KERNEL_SECTORS=$KERNEL_SECTORS -f bin bootloader.asm -o bootloader.bin

# 8) Crear imagen de disco de 10 MiB
echo "Creando imagen de disco de 10MB..."
dd if=/dev/zero of=hdd.img bs=512 count=20480

# 9) Escribir bootloader en sector 0
echo "Escribiendo bootloader en hdd.img..."
dd if=bootloader.bin of=hdd.img bs=512 seek=0 conv=notrunc

# 10) Escribir kernel.bin a partir del sector 1
echo "Escribiendo kernel.bin en sector 1..."
dd if=kernel.bin of=hdd.img bs=512 seek=1 conv=notrunc

# 11) Iniciar QEMU
echo "Iniciando QEMU desde hdd.img..."
qemu-system-x86_64 -drive format=raw,file=hdd.img
