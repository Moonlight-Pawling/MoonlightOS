[BITS 16]
[ORG 0x7C00]

; Constantes
%define KERNEL_SEGMENT  0x0000
%define KERNEL_OFFSET   0x8000
%define KERNEL_LBA      2         ; Sector 2 (tercer sector físico)

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    
    mov [boot_drive], dl
    
    mov si, msg_loading
    call print_string
    
    ; --- NUEVA VERSIÓN: USAR LECTURA CHS MÁS SIMPLE ---
    mov ax, KERNEL_SEGMENT
    mov es, ax
    mov bx, KERNEL_OFFSET
    
    mov ah, 0x02            ; INT 13h: Read sectors
    mov al, 32              ; Leer varios sectores (suficientes para el kernel)
    mov ch, 0               ; Cilindro 0
    mov cl, 3               ; Sector 3 (= LBA 2)
    mov dh, 0               ; Cabeza 0
    mov dl, [boot_drive]    ; Unidad
    
    int 0x13                ; Leer sectores
    jc disk_error
    
    ; --- DIAGNÓSTICO PRE-SALTO ---
    mov si, msg_loaded
    call print_string
    
    ; Verificar bytes en 0000:8000
    xor ax, ax
    mov es, ax
    mov al, [es:0x8000]     ; Primer byte
    call print_hex_byte
    mov al, [es:0x8001]     ; Segundo byte
    call print_hex_byte
    
    ; Pausa para diagnóstico
    mov si, msg_press
    call print_string
    xor ah, ah
    int 0x16
    
    ; --- PREPARAR PARA SALTO ---
    cli                     ; Deshabilitar interrupciones
    xor ax, ax              ; Limpiar registros críticos
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, 0x7C00
    
    ; Pasar la unidad de arranque al kernel
    mov dl, [boot_drive]
    
    ; Saltar al kernel
    jmp KERNEL_SEGMENT:KERNEL_OFFSET

disk_error:
    mov si, msg_error
    call print_string
    jmp $

; --- FUNCIONES DE AYUDA ---
print_string:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret

print_hex_byte:
    push ax
    push cx
    
    mov cx, 2
.loop:
    rol al, 4
    mov ah, al
    and ah, 0x0F
    add ah, '0'
    cmp ah, '9'
    jle .print
    add ah, 7          ; 'A'-'9'-1
.print:
    push ax
    mov al, ah
    mov ah, 0x0E
    int 0x10
    pop ax
    loop .loop
    
    pop cx
    pop ax
    ret

; --- DATA ---
boot_drive db 0
msg_loading db "Cargando kernel...", 0
msg_loaded db " Bytes: ", 0
msg_press db " Presiona tecla", 0
msg_error db " Error!", 0

; --- PADDING AND SIGNATURE ---
times 510-($-$$) db 0
dw 0xAA55