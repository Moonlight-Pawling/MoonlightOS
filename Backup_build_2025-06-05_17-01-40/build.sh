#!/bin/bash
set -e

# ---------------------------------------------
# 1) Preguntar si queremos guardar backups
# ---------------------------------------------
read -p "¿Guardar copia de builds anteriores? (y/n): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    mkdir -p "Backup_build_$timestamp"
    cp bootloader.asm kernel.asm kernel.c linker.ld build.sh \
       "Backup_build_$timestamp/" 2>/dev/null || true
    cp bootloader.bin kernel_trampoline.o kernel.elf kernel.o \
       kernel.bin hdd.img "Backup_build_$timestamp/" 2>/dev/null || true
fi

# ---------------------------------------------
# 2) Limpiar builds anteriores
# ---------------------------------------------
rm -f bootloader.bin kernel_trampoline.o kernel.elf kernel.o \
      kernel.bin hdd.img kernel_size.inc

# ---------------------------------------------
# 3) Generar kernel_size.inc provisional
#    (necesario para compilar bootloader.asm)
# ---------------------------------------------
#    Ponemos un valor "grande" que seguro cubra el kernel.
#    Luego lo reescribiremos con el valor real.
DUMMY_SECTORS=1000
echo "KERNEL_SECTORS equ $DUMMY_SECTORS" > kernel_size.inc

# ---------------------------------------------
# 4) Compilar bootloader (ASM 16 bits, usa KERNEL_SECTORS)
# ---------------------------------------------
echo "Compilando bootloader (ASM, modo real)..."
nasm -f bin bootloader.asm -o bootloader.bin

# ---------------------------------------------
# 5) Compilar kernel.asm (stub 16→32→64 bits) como ELF64
# ---------------------------------------------
echo "Compilando kernel.asm (stub 16/32/64 bits) como ELF64..."
nasm -f elf64 kernel.asm -o kernel_trampoline.o

# ---------------------------------------------
# 6) Compilar kernel.c (modo largo)
# ---------------------------------------------
echo "Compilando kernel en C (modo largo)..."
x86_64-elf-gcc -ffreestanding -mno-red-zone -m64 -c kernel.c -o kernel.o

# ---------------------------------------------
# 7) Linkear todo con linker.ld
# ---------------------------------------------
echo "Linkeando kernel completo con linker.ld..."
x86_64-elf-ld -nostdlib -T linker.ld kernel_trampoline.o kernel.o -o kernel.elf

# ---------------------------------------------
# 8) Extraer binario plano del ELF
# ---------------------------------------------
echo "Generando kernel.bin plano..."
x86_64-elf-objcopy -O binary kernel.elf kernel.bin

# ---------------------------------------------
# 9) Recalcular KERNEL_SECTORS con el tamaño real
# ---------------------------------------------
KERNEL_SIZE=$(stat --format=%s kernel.bin)
KERNEL_SECTORS=$(( (KERNEL_SIZE + 511) / 512 ))
echo "Kernel: $KERNEL_SIZE bytes = $KERNEL_SECTORS sectores"
echo "KERNEL_SECTORS equ $KERNEL_SECTORS" > kernel_size.inc

# ---------------------------------------------
# 10) Recompilar sólo el bootloader con el valor real
#     de KERNEL_SECTORS en kernel_size.inc
# ---------------------------------------------
echo "Recompilando bootloader (ASM) con KERNEL_SECTORS=$KERNEL_SECTORS..."
nasm -f bin bootloader.asm -o bootloader.bin

# ---------------------------------------------
# 11) Crear imagen de disco de 10 MiB
# ---------------------------------------------
echo "Creando imagen de disco de 10MB..."
dd if=/dev/zero of=hdd.img bs=512 count=20480

# ---------------------------------------------
# 12) Escribir bootloader en el primer sector
# ---------------------------------------------
echo "Escribiendo bootloader en hdd.img..."
dd if=bootloader.bin of=hdd.img bs=512 seek=0 conv=notrunc

# ---------------------------------------------
# 13) Escribir kernel.bin a partir del sector 1
# ---------------------------------------------
echo "Escribiendo kernel.bin en sector 1..."
dd if=kernel.bin of=hdd.img bs=512 seek=1 conv=notrunc

# ---------------------------------------------
# 14) Iniciar QEMU
# ---------------------------------------------
echo "Iniciando QEMU desde hdd.img..."
qemu-system-x86_64 -drive format=raw,file=hdd.img
