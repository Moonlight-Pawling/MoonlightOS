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

# Compilar kernel.asm (stub 16→32→64 bits) como ELF64
echo "Compilando kernel.asm (stub 16/32/64 bits) como ELF64..."
nasm -f elf64 -g kernel.asm -o kernel_trampoline.o

# Compilar kernel.c (modo largo, C)
echo "Compilando kernel en C (modo largo)..."
x86_64-elf-gcc -ffreestanding -mno-red-zone -m64 -g -c kernel.c -o kernel.o

# Linkear kernel_trampoline.o + kernel.o en kernel.elf
echo "Linkeando kernel completo con linker.ld..."
x86_64-elf-ld -nostdlib -T linker.ld kernel_trampoline.o kernel.o -o kernel.elf

# Extraer a binario plano
echo "Generando kernel.bin plano..."
x86_64-elf-objcopy -O binary kernel.elf kernel.bin

# Después de generar kernel.bin:
echo "Verificando kernel.bin:"
ls -la kernel.bin
echo "Primeros bytes del kernel:"
hexdump -C -n 16 kernel.bin

# 6) Calcular cuántos sectores ocupa kernel.bin
KERNEL_SIZE=$(stat --format=%s kernel.bin)
KERNEL_SECTORS=$(( (KERNEL_SIZE + 511) / 512 ))
echo "Kernel: $KERNEL_SIZE bytes = $KERNEL_SECTORS sectores"
echo "IMPORTANTE: Asegúrate de que este valor coincida con KERNEL_SECTORS en bootloader.asm"

# Compilar bootloader, pasándole KERNEL_SECTORS con -D
echo "Compilando bootloader (ASM, modo real) con KERNEL_SECTORS=$KERNEL_SECTORS..."
nasm -D KERNEL_SECTORS=$KERNEL_SECTORS -f bin bootloader.asm -o bootloader.bin

# Crear imagen de disco de 10MB
echo "Creando imagen de disco de 10MB..."
dd if=/dev/zero of=hdd.img bs=512 count=20480

# 9) Escribir bootloader en primer sector
echo "Escribiendo bootloader en hdd.img..."
dd if=bootloader.bin of=hdd.img bs=512 seek=0 conv=notrunc

# 10) Escribir kernel.bin a partir del sector N (MODIFICADO - ERA SECTOR 1)
echo "Escribiendo kernel.bin en sector 2..."
dd if=kernel.bin of=hdd.img bs=512 seek=1 conv=notrunc

# Examinar el contenido de la imagen
echo "Verificando contenido de la imagen en los primeros sectores:"
hexdump -C -n 1536 hdd.img  # Muestra los primeros 3 sectores

# 12) Inicia QEMU con opciones de depuración
echo "Iniciando QEMU desde hdd.img..."
qemu-system-x86_64 -drive file=hdd.img,format=raw,index=0,media=disk -boot c -monitor stdio