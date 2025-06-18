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
rm -f bootloader.bin kernel_trampoline.o kernel.elf kernel.o kernel.bin hdd.img

echo "Compilando bootloader..."
nasm -f bin bootloader.asm -o bootloader.bin

echo "Compilando kernel 64-bit..."
nasm -f elf64 kernel.asm -o kernel_trampoline.o
x86_64-elf-gcc -m64 -ffreestanding -mcmodel=kernel -c kernel.c -o kernel.o
x86_64-elf-ld -nostdlib -T linker.ld kernel_trampoline.o kernel.o -o kernel.elf
x86_64-elf-objcopy -O binary kernel.elf kernel.bin

# Calcular tamaño del kernel en sectores (512 bytes) y actualizar la cabecera (4 bytes LE)
kernel_size=$(stat -c %s kernel.bin)
kernel_sectors=$(( (kernel_size + 511) / 512 ))

# Nuevo límite a 1GB (2,097,152 sectores)
if [ "$kernel_sectors" -gt 2097152 ]; then
    echo "ERROR: El kernel excede 1GB ($kernel_sectors sectores)"
    exit 1
fi

echo "Tamaño del kernel: $kernel_size bytes ($kernel_sectors sectores)"

# Guardar valor original de la firma mágica (bytes 4 y 5)
MAGIC_BYTES=$(dd if=kernel.bin bs=1 skip=4 count=2 status=none | hexdump -v -e '1/1 "%02X"')

# Actualizar los primeros 4 bytes de kernel.bin con el número de sectores (little-endian)
le_bytes=$(printf "%08x" $kernel_sectors | sed 's/../& /g' | awk '{for(i=4;i>=1;i--) printf "%s", $i}')
printf "\\x${le_bytes:0:2}\\x${le_bytes:2:2}\\x${le_bytes:4:2}\\x${le_bytes:6:2}" | \
    dd of=kernel.bin bs=1 seek=0 count=4 conv=notrunc status=none

# (Opcional) Verificar que la actualización de la cabecera fue exitosa
NEW_SIZE_BYTES=$(dd if=kernel.bin bs=1 count=4 status=none | hexdump -v -e '1/1 "%02X"')
echo "Cabecera actualizada: Tamaño=$NEW_SIZE_BYTES, Firma=$MAGIC_BYTES"

echo "Primeros bytes del kernel 64-bit (incluyendo tamaño actualizado):"
hexdump -C -n 32 kernel.bin

echo "Creando imagen de disco..."
dd if=/dev/zero of=hdd.img bs=1M count=1024 status=none
dd if=bootloader.bin of=hdd.img bs=512 seek=0 conv=notrunc status=none
dd if=kernel.bin of=hdd.img bs=512 seek=2 conv=notrunc status=none

echo "Configuración de memoria:"
echo "- Memoria física detectada: 1 GB"
echo "- Memoria virtual mapeada: 124 MB"
echo "- Memoria disponible para QEMU: 1 GB"

echo "Iniciando QEMU con soporte 64-bit..."
qemu-system-x86_64 -drive file=hdd.img,format=raw,index=0,media=disk \
                   -boot c -cpu qemu64 -m 1G