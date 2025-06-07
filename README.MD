# Kernel de 32 bits

Un kernel básico en modo protegido de 32 bits. Este proyecto implementa un sistema operativo mínimo que arranca desde el modo real (16 bits), transiciona a modo protegido (32 bits) y ejecuta código en C.

## Requisitos

Para compilar y ejecutar este proyecto se necesita:

- **NASM** - Ensamblador para el código de arranque
- **GCC cross-compiler (x86_64-elf)** - Para compilar el código C del kernel
- **GNU Binutils (ld, objcopy)** - Para enlazar y convertir los archivos objeto
- **QEMU** - Para emular y ejecutar el sistema operativo
- **Bash** - Para ejecutar el script de construcción

### Instalación de dependencias

#### En sistemas basados en Debian/Ubuntu:
```bash
sudo apt update
sudo apt install nasm qemu-system-x86
```

#### Para el cross-compiler:
Es necesario compilar manualmente o descargar un toolchain precompilado de x86_64-elf-gcc. 
Más información: [OSDev Wiki - GCC Cross-Compiler](https://wiki.osdev.org/GCC_Cross-Compiler)

## Clonar el repositorio

```bash
git clone https://github.com/Moonlight-Pawling/MoonlightOS.git
cd MoonlightOS
```

## Compilación

El proyecto incluye un script de construcción que automatiza todo el proceso:

```bash
chmod +x build.sh  # Asegurar que el script sea ejecutable
./build.sh
```

El script te preguntará si deseas guardar una copia de compilaciones anteriores la copia se realiza junto con el propio build.sh, con la finalidad de que se pueda replicar la compilación con los parámetros exactos con los que fueron generados.
Responda 'y' para crear un respaldo o 'n' para no guardar copias.

### Proceso de compilación

El script `build.sh` realiza las siguientes acciones:

1. (Opcional) Crea un respaldo de los archivos fuente y binarios
2. Limpia archivos de compilaciones previas
3. Compila el bootloader con NASM
4. Compila y enlaza el kernel
5. Crea una imagen de disco que incluye bootloader y kernel
6. Lanza QEMU para ejecutar el sistema

## Estructura del proyecto

- `bootloader.asm` - Código de arranque (16 bits)
- `kernel.asm` - Código de inicialización del kernel (16 bits → 32 bits)
- `kernel.c` - Funciones principales del kernel en C
- `linker.ld` - Script de enlazado para el kernel
- `build.sh` - Script de compilación y ejecución

## Detalles técnicos

- El bootloader carga el kernel en la dirección 0x8000
- El kernel inicializa el hardware básico y configura el GDT
- Se realiza la transición de modo real (16 bits) a modo protegido (32 bits)
- El código C se ejecuta en modo protegido con acceso directo al hardware
- El kernel tiene acceso a la memoria de video para mostrar texto

## Depuración

Para depurar el sistema con GDB:

```bash
# Modificar el comando QEMU en build.sh añadiendo:
qemu-system-x86_64 -drive file=hdd.img,format=raw,index=0,media=disk -boot c -s -S

# En otra terminal:
gdb
(gdb) target remote localhost:1234
(gdb) set architecture i8086    # Para inicio en modo real
```

## Uso y modificación

Este código es libre para ser utilizado, estudiado y modificado. Siéntase libre de hacer un fork del repositorio y adaptarlo a sus necesidades.

## Colaboración

Este repositorio no aceptará commits de ningún tipo, por el simple hecho de ser un proyecto educativo sin ninguna intención más allá de mi propio aprendizaje.
