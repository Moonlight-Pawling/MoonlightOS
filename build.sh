#!/bin/bash
set -e

echo "=== MoonlightOS Build System ==="

read -p "¿Guardar copia de builds anteriores? (y/n): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    mkdir -p "Backups"
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    backup_dir="Backups/Backup_build64_$timestamp"
    mkdir -p "$backup_dir"
    
    echo "Guardando backup en $backup_dir..."
    cp bootloader.asm kernel.asm kernel.c linker.ld build.sh \
       "$backup_dir/" 2>/dev/null || true
    
    cp *.bin *.o *.elf hdd.img "$backup_dir/" 2>/dev/null || true
fi

# Limpiar builds anteriores
rm -f bootloader.bin kernel_trampoline.o kernel.elf kernel.o \
      kernel.bin hdd.img

echo "Compilando bootloader..."
nasm -f bin bootloader.asm -o bootloader.bin

echo "Compilando kernel 64-bit..."
nasm -f elf64 kernel.asm -o kernel_trampoline.o
x86_64-elf-gcc -m64 -ffreestanding -mcmodel=kernel -c kernel.c -o kernel.o
x86_64-elf-ld -nostdlib -T linker.ld kernel_trampoline.o kernel.o -o kernel.elf
x86_64-elf-objcopy -O binary kernel.elf kernel.bin

# Calcular tamaño del kernel en sectores (512 bytes) y actualizar la cabecera
kernel_size=$(stat -c %s kernel.bin)
kernel_sectors=$(( (kernel_size + 511) / 512 ))
echo "Tamaño del kernel: $kernel_size bytes ($kernel_sectors sectores)"

# Actualizar los primeros 2 bytes de kernel.bin con el número de sectores
printf "\\$(printf %03o $kernel_sectors)\\0" | dd of=kernel.bin bs=1 count=2 conv=notrunc

echo "Primeros bytes del kernel 64-bit (incluyendo tamaño actualizado):"
hexdump -C -n 32 kernel.bin

echo "Creando imagen de disco..."
dd if=/dev/zero of=hdd.img bs=1M count=64
dd if=bootloader.bin of=hdd.img bs=512 seek=0 conv=notrunc
dd if=kernel.bin of=hdd.img bs=512 seek=2 conv=notrunc

echo "Iniciando QEMU con soporte 64-bit..."
qemu-system-x86_64 -drive file=hdd.img,format=raw,index=0,media=disk \
                   -boot c -cpu qemu64 -m 1G