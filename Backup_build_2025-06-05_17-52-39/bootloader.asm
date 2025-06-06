[BITS 16]
[ORG 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov dl, [boot_drive]        ; Guardar unidad de arranque

    ; --- Mostrar mensaje inicial ---
    mov si, msg_loading
.print_char:
    lodsb
    or al, al
    jz .load_kernel
    mov ah, 0x0E
    int 0x10
    jmp .print_char

.load_kernel:
    ; Leer KERNEL_SECTORS sectores del kernel a 0x0000:0x8000
    mov ah, 0x02
    mov al, KERNEL_SECTORS       ; <<< Definido al compilar con -D KERNEL_SECTORS=...
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    xor ax, ax
    mov es, ax                   ; Segmento = 0x0000
    mov bx, 0x8000               ; Offset = 0x8000
    int 0x13
    jc .disk_error

    ; --- Mostrar mensaje de kernel cargado ---
    mov si, msg_loaded
.print2:
    lodsb
    or al, al
    jz .jump_to_kernel
    mov ah, 0x0E
    int 0x10
    jmp .print2

.jump_to_kernel:
    ; Salto far a 0x0000:0x8000 (etiqueta start de kernel.asm)
    jmp 0x0000:0x8000

.disk_error:
    mov si, msg_disk_error
.print_err:
    lodsb
    or al, al
    jz .hang
    mov ah, 0x0E
    int 0x10
    jmp .print_err

.hang:
    cli
    hlt
    jmp .hang

; --- Mensajes ---
msg_loading       db "Bootloader: cargando kernel...", 0
msg_loaded        db " Kernel cargado, saltando...", 0
msg_disk_error    db " Error leyendo disco.", 0

boot_drive        db 0             ; Aquí guardamos DL

; Relleno hasta 510 bytes y firma 0xAA55
times 510 - ($ - $$) db 0
dw 0xAA55
