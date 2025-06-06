[BITS 16]
[ORG 0x7C00]

; Constantes MODIFICADAS
%define KERNEL_SEGMENT  0x1000    ; Cambiado a 0x1000 en lugar de 0x0000
%define KERNEL_OFFSET   0x0000    ; Cambiado a 0x0000 en lugar de 0x8000
%define KERNEL_LBA      1         ; Probar con sector 1 de nuevo

start:
    ; [resto del código]
    
.load_complete:
    ; --- DIAGNÓSTICO EXTENDIDO ---
    mov si, msg_check
    call print_string
    
    ; Segmento:offset de carga
    mov ax, [current_segment]
    call print_hex
    mov al, ':'
    call print_char
    mov ax, [current_offset]
    call print_hex
    
    mov si, msg_bytes
    call print_string
    
    ; Ver bytes en KERNEL_SEGMENT:KERNEL_OFFSET
    mov es, [current_segment]    ; Usar el segmento actual
    mov bx, [current_offset]     ; Y el offset actual 
    
    ; Leer los 4 primeros bytes donde debería estar el kernel
    mov al, [es:0]
    call print_hex_byte
    mov al, [es:1]
    call print_hex_byte
    mov al, [es:2]
    call print_hex_byte
    mov al, [es:3]
    call print_hex_byte
    
    ; Y también probar en la dirección 0x8000 absoluta
    mov si, msg_abs
    call print_string
    
    xor ax, ax
    mov es, ax
    mov al, [es:0x8000]
    call print_hex_byte
    mov al, [es:0x8001]
    call print_hex_byte
    
    ; Pausa
    mov si, msg_press
    call print_string
    xor ah, ah
    int 0x16
    
    ; Saltar al kernel en el nuevo segmento
    mov dl, [boot_drive]
    jmp KERNEL_SEGMENT:KERNEL_OFFSET

; [resto del código]

msg_loading db "Cargando kernel", 0
msg_check   db " OK @ ", 0
msg_bytes   db " Bytes: ", 0
msg_abs     db " Abs8000: ", 0  ; Nueva etiqueta
msg_press   db " Tecla->", 0
msg_error   db " Error!", 0