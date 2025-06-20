# MoonlightOS: Kernel de 64 bits

Un kernel avanzado en modo largo de 64 bits (x86_64). Este proyecto implementa un sistema operativo que arranca desde el modo real (16 bits), transiciona a modo protegido (32 bits), configura paginación y finalmente entra en modo largo (64 bits) para ejecutar código en C.

## Características

- Bootloader personalizado que carga el kernel
- Transición completa de 16 bits → 32 bits → 64 bits
- Sistema de procesos básico
- Consola interactiva con shell "Portal"
- Monitorización de recursos del sistema
- Gestión de memoria con paginación
- Soporte para comandos y aplicaciones básicas

## Requisitos

Para compilar y ejecutar este proyecto se necesita:

- **NASM** - Ensamblador para el código de arranque y transición a 64 bits
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

El script te preguntará si deseas guardar una copia de compilaciones anteriores, útil si se quiere guardar un estado funcional antes de implementar modificaciones. La copia se realiza junto con el propio `build.sh`, ya que para replicar de forma correcta el estado que se espera, se deben incluir los parámetros exactos de compilación con los que los archivos fueron generados.
```bash
=== MoonlightOS Build System ===
¿Guardar copia de builds anteriores? (y/n): 
```


### Proceso de compilación

El script `build.sh` realiza las siguientes acciones:

1. (Opcional) Crea un respaldo de los archivos fuente y binarios
2. Limpia archivos de compilaciones previas
3. Compila el bootloader con NASM
4. Compila el código de arranque del kernel (ASM)
5. Compila el código principal del kernel (C)
6. Enlaza ambas partes mediante linker.ld
7. Crea una imagen de disco que incluye bootloader y kernel
8. Lanza QEMU para ejecutar el sistema

## Estructura del proyecto

- `bootloader.asm` - Código de arranque (16 bits)
- `kernel.asm` - Código de inicialización del kernel y transición a 64 bits
- `kernel.c` - Funciones principales del kernel en C
- `linker.ld` - Script de enlazado para el kernel
- `build.sh` - Script de compilación y ejecución
- `fs.h` - Definiciones para el sistema de archivos (en desarrollo)

## Detalles técnicos

- El bootloader carga el kernel en la dirección 0x8000
- El kernel inicializa el hardware básico y configura el GDT
- Se realiza la transición de modo real (16 bits) a modo protegido (32 bits)
- Se configura la paginación necesaria para modo largo
- Se habilita el modo largo (64 bits) a través de registros MSR
- El kernel C se ejecuta en modo largo con todas las capacidades de 64 bits
- Sistema de procesos simple que permite multitarea cooperativa
- Consola interactiva con intérprete de comandos "Portal"
- Monitorización de recursos del sistema en tiempo real

## Componentes del Sistema

### MoonlightOS Core
- **Bootloader**: Carga el kernel desde disco y lo ejecuta
- **Kernel ASM**: Maneja la inicialización y cambio de modo
- **Kernel C**: Componente principal con funcionalidades del sistema

### Portal Shell
- Shell interactiva que permite ejecutar comandos
- Gestión de procesos (listar, iniciar, detener)
- Comandos básicos del sistema

### Monitores del Sistema
- Monitorización de RAM
- Contador de procesos activos
- Reloj del sistema

## Depuración

Para depurar el sistema con GDB:

```bash
# Modificar el comando QEMU en build.sh añadiendo:
qemu-system-x86_64 -drive file=hdd.img,format=raw,index=0,media=disk -boot c -s -S

# En otra terminal:
gdb
(gdb) target remote localhost:1234
(gdb) set architecture i8086    # Para inicio en modo real
(gdb) b *0x8000                 # Breakpoint al inicio del kernel
```

## Uso y modificación

Este código es libre para ser utilizado, estudiado y modificado. Siéntase libre de hacer un fork del repositorio y adaptarlo a sus necesidades.

## Colaboración

Este repositorio no aceptará commits de ningún tipo, por el simple hecho de ser un proyecto educativo sin ninguna intención más allá de mi propio aprendizaje.

## Nota Técnica

Este proyecto fue desarrollado y probado en Nobara 41 (basado en Fedora) utilizando el IDE CLion de JetBrains.
IA's usadas: Github Copilot (Chat GPT 4.1 y Claude Sonnet 3.7).
