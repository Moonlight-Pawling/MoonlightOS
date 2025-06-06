[BITS 16]
[ORG 0x7C00]

; Constantes de segmentos para cargar el kernel
%define KERNEL_SEGMENT  0x0000    ; Segmento inicial para cargar el kernel
%define KERNEL_OFFSET   0x8000    ; Offset inicial para cargar el kernel

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti                         ; Re-habilitar interrupciones

    mov [boot_drive], dl        ; Guardar unidad de arranque

    ; --- Mostrar mensaje inicial ---
    mov si, msg_loading
    call print_string

    ; --- Inicializar variables para la carga ---
    mov [sectors_left], word KERNEL_SECTORS  ; Total de sectores a cargar
    mov word [current_segment], KERNEL_SEGMENT
    mov word [current_offset], KERNEL_OFFSET
    mov word [current_sector], 2             ; Empezamos en sector 2

.load_loop:
    mov ax, [sectors_left]       ; Verificar si terminamos
    test ax, ax
    jz .load_complete

    ; Determinar cuántos sectores cargar en esta iteración (max 63)
    mov cx, 63                   ; Máximo por operación (seguro)
    cmp cx, [sectors_left]       ; Si quedan menos, usar ese valor
    jb .use_max
    mov cx, [sectors_left]
.use_max:
    mov [sectors_to_read], cx

    ; Mostrar progreso
    mov al, '.'
    call print_char

    ; Configurar registros para INT 13h
    mov ax, [current_segment]
    mov es, ax                   ; ES:BX = dirección destino
    mov bx, [current_offset]
    
    mov ah, 0x02                 ; Función de lectura
    mov al, byte [sectors_to_read] ; Número de sectores a leer
    mov ch, byte [current_track] ; Cilindro
    mov cl, byte [current_sector] ; Sector
    mov dh, byte [current_head]  ; Cabeza
    mov dl, [boot_drive]         ; Unidad de disco
    
    int 0x13                     ; Leer sectores
    jc .disk_error               ; Si CF=1, hubo error

    ; Actualizar contadores
    mov ax, [sectors_to_read]
    sub [sectors_left], ax       ; Restar sectores leídos
    
    ; Actualizar posición en memoria
    ; Cada sector = 512 bytes, así que multiply * 512 (o shift left 9)
    mov ax, [sectors_to_read]
    mov cx, 512
    mul cx                       ; DX:AX = AX * CX
    add [current_offset], ax     ; Sumar bytes al offset
    adc [current_segment], dx    ; Agregar carry al segmento

    ; Actualizar geometría de disco (sector, head, track)
    mov ax, [sectors_to_read]
    add [current_sector], ax     ; Avanzar sectores
    
    ; Verificar si pasamos de sector 63
    cmp byte [current_sector], 64
    jb .load_loop                ; Si no, continuar
    
    ; Si pasamos sector 63, avanzar cabezal/pista
    mov byte [current_sector], 1 ; Volver a sector 1
    inc byte [current_head]      ; Avanzar cabeza
    cmp byte [current_head], 2
    jb .load_loop                ; Si sigue siendo 0 o 1, continuar
    
    mov byte [current_head], 0   ; Volver a cabeza 0
    inc byte [current_track]     ; Avanzar pista
    jmp .load_loop

.load_complete:
    ; --- Mostrar mensaje de éxito ---
    mov si, msg_loaded
    call print_string
    
    ; Saltar al kernel en 0x0000:0x8000
    mov dl, [boot_drive]        ; Pasar unidad de arranque en DL
    jmp KERNEL_SEGMENT:KERNEL_OFFSET

.disk_error:
    ; Mostrar mensaje de error y código
    mov si, msg_disk_error
    call print_string
    mov si, msg_code
    call print_string

    ; Obtener y mostrar código de error
    mov ah, 0x01
    int 0x13                    ; Obtener último código de error
    
    ; Imprimir AH como hex
    mov al, ah
    call print_hex_byte

    jmp halt

; --- Funciones auxiliares ---

; Imprime cadena terminada en cero apuntada por SI
print_string:
    pusha
.loop:
    lodsb                       ; Cargar byte de SI en AL
    test al, al                 ; ¿Es cero?
    jz .done
    call print_char
    jmp .loop
.done:
    popa
    ret

; Imprime carácter en AL
print_char:
    pusha
    mov ah, 0x0E                ; Función TTY
    int 0x10
    popa
    ret

; Imprime byte en AL como hexadecimal
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

; Imprime dígito hexadecimal en AL (0-15)
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
    jmp halt                    ; Por si acaso se reanuda tras NMI

; --- Variables y datos ---
boot_drive       db 0
current_track    db 0
current_head     db 0
current_sector   db 2
sectors_left     dw 0
sectors_to_read  dw 0
current_segment  dw 0
current_offset   dw 0

; --- Mensajes ---
msg_loading      db "Bootloader: cargando kernel", 0
msg_loaded       db " OK. Saltando al kernel!", 0
msg_disk_error   db " Error leyendo disco!", 0
msg_code         db " Codigo: 0x", 0

; --- Rellenar y firma de bootsector ---
times 510 - ($ - $$) db 0
dw 0xAA55