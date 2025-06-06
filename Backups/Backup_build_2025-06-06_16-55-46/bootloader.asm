[BITS 16]
[ORG 0x7C00]

; Constantes MODIFICADAS
%define KERNEL_SEGMENT  0x1000    ; Cambiado a 0x1000 en lugar de 0x0000
%define KERNEL_OFFSET   0x0000    ; Cambiado a 0x0000 en lugar de 0x8000
%define KERNEL_LBA      1         ; Probar con sector 1 de nuevo

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti                         ; Re-habilitar interrupciones

    mov byte [boot_drive], dl   ; Guardar unidad de arranque

    ; --- Mensaje inicial ---
    mov si, msg_loading
    call print_string

    ; --- Inicializar para carga ---
    mov [sectors_remaining], word KERNEL_SECTORS
    mov ax, KERNEL_SEGMENT
    mov [current_segment], ax
    mov ax, KERNEL_OFFSET
    mov [current_offset], ax
    mov ax, KERNEL_LBA          ; ¡Cambio crucial! Comenzar desde KERNEL_LBA
    mov [current_lba], ax

.load_loop:
    ; Verificar si terminamos
    mov ax, [sectors_remaining]
    test ax, ax
    jz .load_complete

    ; --- DETERMINAR CUÁNTOS SECTORES LEER ---
    ; Operación simplificada para ahorrar bytes
    mov ax, 32                  ; Leer máximo 32 sectores por operación
    cmp ax, [sectors_remaining]
    jbe .do_read
    mov ax, [sectors_remaining]
    
.do_read:
    mov [sectors_to_read], ax
    
    ; Mostrar progreso
    mov al, '.'
    call print_char

    ; --- LECTURA DE DISCO ---
    mov bx, [current_offset]
    mov es, [current_segment]
    
    mov ah, 0x42               ; Función Extended Read (LBA)
    mov dl, [boot_drive]       ; Unidad
    
    ; Disk Address Packet en el stack
    push word 0 
    push word 0
    push word [current_segment]
    push word bx
    push word [current_lba]
    push word 0
    push word ax
    push word 16
    
    mov si, sp
    int 0x13
    add sp, 16
    jc .disk_error

    ; --- ACTUALIZAR CONTADORES ---
    mov ax, [sectors_to_read]
    sub [sectors_remaining], ax
    add [current_lba], ax
    
    ; Actualizar posición de memoria
    mov ax, [sectors_to_read]
    shl ax, 9                   ; Multiplicar por 512
    add [current_offset], ax
    
    ; Si hay overflow, ajustar el segmento
    jnc .no_segment_adjust
    add word [current_segment], 0x1000  ; +64K
    mov word [current_offset], 0
    
.no_segment_adjust:
    jmp .load_loop

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

.disk_error:
    mov si, msg_error
    call print_string
    jmp halt

; --- FUNCIONES COMPACTAS ---
print_string:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret

print_char:
    mov ah, 0x0E
    int 0x10
    ret

print_hex:
    ; Imprimir palabra hex (AX)
    mov cx, 4
.digit:
    rol ax, 4
    mov bl, al
    and bl, 0x0F
    add bl, '0'
    cmp bl, '9'
    jle .print
    add bl, 'A' - '9' - 1
.print:
    mov al, bl
    call print_char
    loop .digit
    ret

print_hex_byte:
    ; Imprimir byte hex (AL)
    mov ah, al
    shr al, 4
    call print_hex_digit
    mov al, ah
    and al, 0x0F
    call print_hex_digit
    ret

print_hex_digit:
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .print
    add al, 'A' - '9' - 1
.print:
    call print_char
    ret

halt:
    cli
    hlt
    jmp halt

; --- DATOS ---
boot_drive        db 0
sectors_remaining dw 0
sectors_to_read   dw 0
current_segment   dw 0
current_offset    dw 0
current_lba       dw 0

; --- MENSAJES COMPACTOS ---
msg_loading db "Cargando kernel", 0
msg_check   db " OK @ ", 0
msg_bytes   db " Bytes: ", 0
msg_abs     db " Abs8000: ", 0  ; Nueva etiqueta
msg_press   db " Tecla->", 0
msg_error   db " Error!", 0

; Relleno y firma
times 510-($-$$) db 0
dw 0xAA55