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
nasm -f elf64 -g kernel.asm -o kernel_trampoline.o

# 3) Compilar kernel.c (modo largo, C)
echo "Compilando kernel en C (modo largo)..."
x86_64-elf-gcc -ffreestanding -mno-red-zone -m64 -g -c kernel.c -o kernel.o

# 4) Linkear kernel_trampoline.o + kernel.o en kernel.elf
echo "Linkeando kernel completo con linker.ld..."
x86_64-elf-ld -nostdlib -T linker.ld kernel_trampoline.o kernel.o -o kernel.elf

# 5) Extraer a binario plano
echo "Generando kernel.bin plano..."
x86_64-elf-objcopy -O binary kernel.elf kernel.bin

# 6) Calcular cuántos sectores ocupa kernel.bin
KERNEL_SIZE=$(stat --format=%s kernel.bin)
KERNEL_SECTORS=$(( (KERNEL_SIZE + 511) / 512 ))
echo "Kernel: $KERNEL_SIZE bytes = $KERNEL_SECTORS sectores"

# 7) Compilar bootloader, pasándole KERNEL_SECTORS con -D
echo "Compilando bootloader (ASM, modo real) con KERNEL_SECTORS=$KERNEL_SECTORS..."
nasm -D KERNEL_SECTORS=$KERNEL_SECTORS -f bin bootloader.asm -o bootloader.bin

# 8) Verificar firma del bootsector
echo "Verificando firma del bootsector..."
SIGNATURE=$(hexdump -n 2 -s 510 -e '"%04x"' bootloader.bin)
if [ "$SIGNATURE" != "aa55" ]; then
    echo "ERROR: Firma de bootsector incorrecta. Encontrada: $SIGNATURE, esperada: aa55"
    exit 1
fi
echo "Firma correcta: 0xAA55"

# 9) Crear imagen de disco de 10 MiB
echo "Creando imagen de disco de 10MB..."
dd if=/dev/zero of=hdd.img bs=512 count=20480

# 10) Escribir bootloader en primer sector
echo "Escribiendo bootloader en hdd.img..."
dd if=bootloader.bin of=hdd.img bs=512 seek=0 conv=notrunc

# 11) Escribir kernel.bin a partir del sector 1
echo "Escribiendo kernel.bin en sector 1..."
dd if=kernel.bin of=hdd.img bs=512 seek=1 conv=notrunc

# 12) Verificar que el bootloader está correctamente en la imagen
echo "Verificando bootloader en imagen..."
SIGNATURE_IMG=$(hexdump -n 2 -s 510 -e '"%04x"' hdd.img)
if [ "$SIGNATURE_IMG" != "aa55" ]; then
    echo "ERROR: Firma en imagen incorrecta. Encontrada: $SIGNATURE_IMG, esperada: aa55"
    exit 1
fi
echo "Bootloader correctamente instalado en imagen."

# 13) Iniciar QEMU con opciones explícitas de arranque
echo "Iniciando QEMU desde hdd.img..."
qemu-system-x86_64 \
    -drive file=hdd.img,format=raw,if=ide,index=0,media=disk \
    -boot order=c \
    -monitor stdio \
    -m 128M