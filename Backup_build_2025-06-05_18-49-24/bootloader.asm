[BITS 16]
[ORG 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl        ; Guardar unidad de arranque

    ; --- Mostrar mensaje inicial ---
    mov si, msg_loading
.print_char:
    lodsb
    or al, al
    jz .load_kernel
    mov ah, 0x0E
    int 0x10
    jmp .print_char