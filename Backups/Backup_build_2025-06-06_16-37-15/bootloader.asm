[BITS 16]
[ORG 0x7C00]

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
    ; Verificar si terminamos
    mov ax, [sectors_remaining]
    test ax, ax
    jz .load_complete

    ; --- ARREGLO: CALCULAR LECTURAS SEGURAS ---
    ; Determinar cuántos sectores podemos leer sin cruzar límite de 64K
    mov ax, [current_offset]
    neg ax                      ; -offset
    and ax, 0xFFFF              ; En caso de que fuera 0, ahora será 0
    shr ax, 9                   ; Dividir por 512 para obtener sectores
    
    ; Si es 0, entonces estamos justo en un límite, máximo 128 sectores
    test ax, ax
    jnz .check_safe_sectors
    mov ax, 128                 ; Máximo seguro
    
.check_safe_sectors:
    ; Asegurarse de no exceder 63 sectores (limitación del BIOS)
    cmp ax, 63
    jbe .sectors_ok
    mov ax, 63                  ; Máximo por operación BIOS
    
.sectors_ok:
    ; No leer más de los sectores restantes
    cmp ax, [sectors_remaining]
    jbe .do_read
    mov ax, [sectors_remaining]
    
.do_read:
    ; No leer 0 sectores
    test ax, ax
    jnz .read_nonzero
    mov ax, 1                   ; Leer al menos 1
    
.read_nonzero:
    ; Guardar cuántos sectores leeremos
    mov [sectors_to_read], ax
    
    ; Mostrar progreso con punto
    push ax
    mov al, '.'
    call print_char
    pop ax

    ; --- LECTURA DE DISCO ---
    mov bx, [current_offset]
    mov es, [current_segment]
    
    mov ah, 0x42               ; Función Extended Read (LBA)
    mov dl, [boot_drive]       ; Unidad
    
    ; Setup Disk Address Packet en el stack
    push word 0                ; Offset 64-bit (high dword): 0
    push word 0                ; Offset 64-bit (high dword): 0
    push word [current_segment] ; Segment
    push word bx               ; Offset
    push word [current_lba]    ; LBA (low word)
    push word 0                ; LBA (high word): 0
    push word ax               ; Sectores a leer
    push word 16               ; Tamaño del packet: 16 bytes
    
    mov si, sp                 ; DS:SI -> disk address packet
    int 0x13
    add sp, 16                 ; Limpiar packet del stack
    jc .disk_error

    ; --- ACTUALIZAR CONTADORES ---
    ; Actualizar sectores restantes
    mov ax, [sectors_to_read]
    sub [sectors_remaining], ax
    
    ; Actualizar LBA
    add [current_lba], ax
    
    ; Actualizar posición de memoria
    mov ax, [sectors_to_read]
    mov cx, 512
    mul cx                     ; DX:AX = sectores * 512
    add [current_offset], ax   ; current_offset += bytes_leídos
    
    ; Si hay overflow, ajustar el segmento
    jnc .no_segment_adjust
    add word [current_segment], 0x1000  ; +64K
    mov word [current_offset], 0
    
.no_segment_adjust:
    jmp .load_loop

.load_complete:
    ; Mensaje de éxito
    mov si, msg_loaded
    call print_string
    
    ; *** NUEVO: Verificar segmentos y dónde se cargó ***
    mov si, msg_loading_at
    call print_string
    
    mov ax, [current_segment]   ; Mostrar el segmento final
    call print_hex_word
    mov al, ':'
    call print_char
    mov ax, [current_offset]    ; Mostrar el offset final
    call print_hex_word

    mov si, msg_newline
    call print_string

    ; *** NUEVO: Leer bytes claves del kernel en múltiples localizaciones ***
    mov si, msg_bytes_at_8000
    call print_string
    
    ; Leer en 0000:8000 directamente
    xor ax, ax
    mov es, ax
    mov al, byte [es:0x8000]
    call print_hex_byte
    mov al, byte [es:0x8001]
    call print_hex_byte
    mov al, byte [es:0x8002]
    call print_hex_byte
    mov al, byte [es:0x8003]
    call print_hex_byte
    
    mov si, msg_newline
    call print_string
    
    ; *** Pausa para leer mensajes ***
    mov si, msg_press_key
    call print_string
    xor ah, ah
    int 0x16
    
    ; Saltar al kernel
    mov dl, [boot_drive]
    jmp KERNEL_SEGMENT:KERNEL_OFFSET

.disk_error:
    mov si, msg_disk_error
    call print_string
    
    mov si, msg_code
    call print_string
    mov ah, 0x01
    int 0x13
    mov al, ah
    call print_hex_byte
    
    jmp halt

; --- FUNCIONES AUXILIARES ---

print_string:
    pusha
.loop:
    lodsb
    test al, al
    jz .done
    call print_char
    jmp .loop
.done:
    popa
    ret

print_char:
    pusha
    mov ah, 0x0E
    int 0x10
    popa
    ret

print_hex_byte:
    pusha
    mov cl, al
    shr al, 4
    call print_hex_digit
    mov al, cl
    and al, 0x0F
    call print_hex_digit
    popa
    ret

print_hex_word:
    pusha
    mov cx, ax                ; Guardar el valor
    mov al, ch               ; Byte alto primero
    call print_hex_byte
    mov al, cl               ; Byte bajo después
    call print_hex_byte
    popa
    ret

print_hex_digit:
    pusha
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .print
    add al, 'A' - '9' - 1
.print:
    call print_char
    popa
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

; --- MENSAJES ---
msg_loading       db "Bootloader: cargando kernel", 0
msg_loaded        db " OK.", 0
msg_disk_error    db " Error leyendo disco!", 0
msg_code          db " Codigo: 0x", 0
msg_loading_at    db " Kernel cargado en: ", 0
msg_bytes_at_8000 db " Bytes en 0000:8000: ", 0
msg_newline       db 13, 10, 0
msg_press_key     db " Presiona una tecla para continuar...", 0

; Relleno y firma
times 510-($-$$) db 0
dw 0xAA55