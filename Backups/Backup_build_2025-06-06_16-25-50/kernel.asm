[BITS 16]
;[ORG 0x7C00]

; Constantes
%define KERNEL_SEGMENT  0x0000    ; Segmento inicial
%define KERNEL_OFFSET   0x8000    ; Offset inicial

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
    mov [sectors_remaining], word KERNEL_SECTORS  ; Total de sectores
    mov ax, KERNEL_SEGMENT
    mov [current_segment], ax
    mov ax, KERNEL_OFFSET
    mov [current_offset], ax
    mov ax, 1                   ; Empezar en sector 1 (después del bootsector)
    mov [current_lba], ax

.load_loop:
    ; [código de carga omitido para brevedad]
    ; ...

.load_complete:
    ; Mensaje de éxito
    mov si, msg_loaded
    call print_string
    
    ; Mostrar dirección exacta a donde se saltará
    mov si, msg_jump_to
    call print_string
    
    ; Mostrar segmento
    mov ax, KERNEL_SEGMENT
    call print_hex_word
    
    ; Separador
    mov al, ':'
    call print_char
    
    ; Mostrar offset
    mov ax, KERNEL_OFFSET
    call print_hex_word
    
    mov si, msg_newline
    call print_string
    
    ; Comprobar primer byte del kernel (debe ser 0xB8)
    mov si, msg_first_byte
    call print_string
    
    mov ax, KERNEL_SEGMENT
    mov es, ax
    mov al, byte [es:KERNEL_OFFSET]
    call print_hex_byte
    
    mov si, msg_newline
    call print_string
    
    ; Forzar al usuario a presionar una tecla antes de saltar
    mov si, msg_press_key
    call print_string
    xor ah, ah                  ; AH=0: esperar tecla
    int 0x16                    ; Esperando tecla
    
    ; Saltar al kernel - NUEVA IMPLEMENTACIÓN
    mov dl, [boot_drive]        ; Pasar unidad de arranque
    
    ; Salto manual para garantizar exactitud
    db 0xEA                     ; Opcode para far JMP
    dw KERNEL_OFFSET            ; Offset
    dw KERNEL_SEGMENT           ; Segmento

; [resto del código omitido para brevedad]

msg_jump_to      db "Saltando a direccion ", 0
msg_first_byte   db "Primer byte: ", 0
msg_newline      db 13, 10, 0  ; CR, LF
msg_press_key    db "Presiona cualquier tecla para continuar...", 0

; Función para imprimir número hexadecimal de 16 bits (en AX)
print_hex_word:
    pusha
    push ax
    mov al, ah
    call print_hex_byte
    pop ax
    call print_hex_byte
    popa
    ret