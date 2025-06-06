[BITS 16]
[ORG 0x7C00]

; Constantes
%define KERNEL_SEGMENT  0x0000    ; Segmento de carga
%define KERNEL_OFFSET   0x8000    ; Offset de carga

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
    
    mov [boot_drive], dl
    
    ; --- Mensaje inicial ---
    mov si, msg_loading
    call print_string
    
    ; --- Cargar kernel usando INT 13h/AH=02h (CHS) ---
    ; Convertir LBA 2 a CHS
    ; Sector = (LBA % SPT) + 1
    ; Cabeza = (LBA / SPT) % cabezas
    ; Cilindro = LBA / (SPT * cabezas)
    ; Para simplificar, asumimos SPT=63, cabezas=16
    
    ; Establecer el segmento destino
    mov ax, KERNEL_SEGMENT
    mov es, ax
    
    ; Establecer offset destino
    mov bx, KERNEL_OFFSET
    
    ; Cargar el kernel desde el sector 2 (tercer sector físico)
    ; Sector = 3 (LBA 2 + 1)
    ; Cabeza = 0
    ; Cilindro = 0
    
    mov ah, 0x02            ; INT 13h: Read sectors
    mov al, KERNEL_SECTORS  ; Número de sectores a leer
    mov ch, 0               ; Cilindro 0
    mov cl, 3               ; Sector 3 (numerados desde 1)
    mov dh, 0               ; Cabeza 0
    mov dl, [boot_drive]    ; Unidad
    
    int 0x13                ; Leer sectores
    jc disk_error
    
    ; Verificar bytes usando diagnóstico clásico
    mov si, msg_debug
    call print_string
    
    ; Mostrar primeros bytes en 0000:8000
    xor ax, ax
    mov es, ax
    
    mov al, [es:0x8000]     ; Primer byte
    call print_hex_byte
    mov al, [es:0x8001]     ; Segundo byte
    call print_hex_byte
    
    ; Esperar tecla
    mov ah, 0
    int 0x16
    
    ; Saltar al kernel
    mov dl, [boot_drive]
    jmp KERNEL_SEGMENT:KERNEL_OFFSET
    
disk_error:
    mov si, msg_error
    call print_string
    jmp $
    
; --- Funciones ---
print_string:
    push ax
    push bx
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    pop bx
    pop ax
    ret
    
print_hex_byte:
    push ax
    push bx
    mov bl, al
    shr al, 4
    call print_hex_digit
    mov al, bl
    and al, 0x0F
    call print_hex_digit
    pop bx
    pop ax
    ret
    
print_hex_digit:
    push ax
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .print
    add al, 'A' - '9' - 1
.print:
    mov ah, 0x0E
    int 0x10
    pop ax
    ret
    
; --- Data ---
boot_drive db 0
msg_loading db "Cargando kernel...", 0
msg_debug   db " Bytes en 8000h: ", 0
msg_error   db " Error leyendo disco!", 0

; --- Relleno y firma ---
times 510-($-$$) db 0
dw 0xAA55