#!/bin/bash
set -e

read -p "¿Guardar copia de builds anteriores? (y/n): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    # Asegurar que la carpeta Backups existe
    mkdir -p "Backups"
    
    # Crear subcarpeta con timestamp dentro de Backups
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    backup_dir="Backups/Backup_build_$timestamp"
    mkdir -p "$backup_dir"
    
    # Copiar archivos fuente
    echo "Guardando backup en $backup_dir..."
    cp bootloader.asm kernel.asm kernel.c linker.ld build.sh \
       "$backup_dir/" 2>/dev/null || true
    
    # Copiar archivos compilados
    cp bootloader.bin kernel_trampoline.o kernel.elf kernel.o \
       kernel.bin hdd.img "$backup_dir/" 2>/dev/null || true
fi

# Limpiar builds anteriores
rm -f bootloader.bin kernel_trampoline.o kernel.elf kernel.o kernel.bin hdd.img

# Compilación simplificada
echo "Compilando bootloader..."
nasm -f bin bootloader.asm -o bootloader.bin

echo "Compilando kernel..."
nasm -f elf32 kernel.asm -o kernel_trampoline.o
x86_64-elf-gcc -m32 -ffreestanding -c kernel.c -o kernel.o
x86_64-elf-ld -melf_i386 -nostdlib -T linker.ld kernel_trampoline.o kernel.o -o kernel.elf
x86_64-elf-objcopy -O binary kernel.elf kernel.bin

echo "Primeros bytes del kernel:"
hexdump -C -n 32 kernel.bin

echo "Creando imagen de disco..."
dd if=/dev/zero of=hdd.img bs=1M count=10
dd if=bootloader.bin of=hdd.img bs=512 seek=0 conv=notrunc
dd if=kernel.bin of=hdd.img bs=512 seek=2 conv=notrunc

echo "Iniciando QEMU..."
qemu-system-x86_64 -drive file=hdd.img,format=raw,index=0,media=disk -boot c