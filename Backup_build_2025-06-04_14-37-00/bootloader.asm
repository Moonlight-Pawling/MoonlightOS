[BITS 16]            ; Modo real, instrucciones de 16 bits (BIOS arranca en modo real)
[ORG 0x7C00]         ; Dirección donde la BIOS carga el bootloader (sector 0, 0x7C00h)

start:
    cli                 ; Clear Interrupt Flag: deshabilita interrupciones para evitar que ocurran mientras inicializamos
    xor ax, ax          ; AX = 0 (XOR reg consigo mismo pone 0)
    mov ds, ax          ; DS = 0, establecemos el segmento de datos en 0x0000
    mov es, ax          ; ES = 0, segmento extra también en 0x0000
    mov ss, ax          ; SS = 0, segmento de stack en 0x0000
    mov sp, 0x7C00      ; SP = 0x7C00, apuntamos el stack pointer justo arriba del bootloader (para evitar sobrescribir)

    mov dl, [ds:boot_drive]; Guardamos en memoria el registro DL (unidad de arranque BIOS: 0x00 = floppy, 0x80 = HDD)
    
    ; --- Mostrar mensaje en pantalla ---
	mov si, message; SI apunta al inicio del mensaje a imprimir (posición de memoria)
.print_char:
    lodsb               ; Carga el byte [DS:SI] en AL y aumenta SI automáticamente en 1
    or al, al           ; OR AL con AL: si AL es 0, se pone el flag Zero (fin de cadena)
    jz .load_kernel     ; Si AL = 0 (fin del string), saltar a cargar kernel
    mov ah, 0x0E        ; AH = 0x0E, función BIOS para imprimir carácter en modo teletipo (texto)
    int 0x10            ; Llamar a la interrupción 0x10 del BIOS para imprimir AL en pantalla
    jmp .print_char     ; Volver al siguiente carácter del mensaje

.load_kernel:
    mov ah, 0x02        ; AH = 0x02, función BIOS para leer sectores del disco
    mov al, 20          ; AL = número de sectores a leer (20 sectores para nuestro kernel, ajustar según tamaño)
    mov ch, 0           ; CH = cilindro 0 (cabeza cilindro pista)
    mov cl, 2           ; CL = sector 2 (sector 1 es el bootloader, sector 2 es donde empieza kernel)
    mov dh, 0           ; DH = cabeza 0
    mov dl, [boot_drive]; DL = unidad de disco (guardada antes)
    mov bx, 0x8000      ; BX = offset 0x8000, lugar donde cargar kernel en memoria (segmento ES)
    xor ax, ax 			; Compara ax consigo mismo para obtener 0
    mov es, ax      	; ES = segmento 0x0000, para formar la dirección física ES:BX = 0x00000:0x8000 = 0x8000
    int 0x13            ; Interrupción BIOS para leer sectores del disco en ES:BX
    jc .disk_error      ; Si Carry Flag está activado, hubo error leyendo disco, saltar a error

    ; --- Salto al kernel cargado ---
    jmp 0x0000:0x8000   ; Salto far a segmento 0x0000, offset 0x8000 donde cargamos el kernel

.disk_error:
    mov si, disk_error_msg ; Puntero al mensaje de error
.print_err:
    lodsb
    or al, al
    jz .hang            ; Si llegamos al fin del mensaje saltar a bucle infinito
    mov ah, 0x0E        ; Función BIOS imprimir carácter
    int 0x10
    jmp .print_err      ; Ciclo hasta mostrar todo el mensaje de error

.hang:
    cli                 ; Deshabilitar interrupciones para quedar detenido
    hlt                 ; Halt: detener CPU hasta próxima interrupción (que nunca llegará porque deshabilitamos)
    jmp .hang           ; Bucle infinito para no continuar

; --- Mensajes en memoria ---
message db "Bootloader: cargando kernel...", 0
disk_error_msg db "Error leyendo disco.", 0

boot_drive db 0          ; Aquí guardaremos la unidad de arranque BIOS (DL) para usar en int 0x13

times 510 - ($ - $$) db 0 ; Relleno con ceros hasta llegar a 510 bytes (tamaño boot sector menos firma)
dw 0xAA55                 ; Firma mágica al final del sector para que BIOS reconozca el bootloader (2 bytes)
