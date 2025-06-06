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

# Compilar kernel
nasm -f elf64 -g kernel.asm -o kernel_trampoline.o
x86_64-elf-gcc -ffreestanding -mno-red-zone -m64 -g -c kernel.c -o kernel.o
x86_64-elf-ld -nostdlib -T linker.ld kernel_trampoline.o kernel.o -o kernel.elf
x86_64-elf-objcopy -O binary kernel.elf kernel.bin

# Calcular tamaño del kernel
KERNEL_SIZE=$(stat --format=%s kernel.bin)
KERNEL_SECTORS=$(( (KERNEL_SIZE + 511) / 512 ))
echo "Kernel: $KERNEL_SIZE bytes = $KERNEL_SECTORS sectores"

# Compilar bootloader con el número de sectores
nasm -D KERNEL_SECTORS=$KERNEL_SECTORS -f bin bootloader.asm -o bootloader.bin

# Ver primeros bytes del kernel
echo "Primeros bytes del kernel:"
hexdump -C -n 16 kernel.bin

# Crear imagen de disco
dd if=/dev/zero of=hdd.img bs=1M count=10

# Escribir bootloader al comienzo
dd if=bootloader.bin of=hdd.img bs=512 seek=0 conv=notrunc

# Escribir kernel a partir del sector 2
dd if=kernel.bin of=hdd.img bs=512 seek=2 conv=notrunc

# Iniciar QEMU
qemu-system-x86_64 -drive file=hdd.img,format=raw,index=0,media=disk -boot c