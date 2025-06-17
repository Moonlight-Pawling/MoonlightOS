[BITS 16]
[ORG 0x7C00]

; Constantes
%define KERNEL_SEGMENT  0x0000
%define KERNEL_OFFSET   0x8000
%define KERNEL_LBA      2         ; Sector 2 (tercer sector físico)
%define MAX_SECTORS     127       ; Máximo número de sectores por operación INT 13h

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

    ; --- CARGAR LA CABECERA DEL KERNEL ---
    mov ax, KERNEL_SEGMENT
    mov es, ax
    mov bx, KERNEL_OFFSET

    ; Leer el primer sector del kernel (cabecera)
    mov ah, 0x02            ; INT 13h: Read sectors
    mov al, 1               ; Leer 1 sector (cabecera)
    mov ch, 0               ; Cilindro 0
    mov cl, 3               ; Sector 3 (= LBA 2)
    mov dh, 0               ; Cabeza 0
    mov dl, [boot_drive]    ; Unidad

    int 0x13                ; Leer sector de cabecera
    jc disk_error

    ; --- OBTENER TAMAÑO DEL KERNEL ---
    mov cx, [KERNEL_OFFSET]   ; Obtener tamaño del kernel en sectores
    cmp cx, 0                 ; Si es 0, usar valor predeterminado
    jne .size_ok
    mov cx, 32                ; Valor predeterminado: 32 sectores
.size_ok:
    mov [kernel_sectors], cx  ; Guardar para uso posterior

    ; --- VERIFICAR FIRMA MÁGICA ---
    cmp word [KERNEL_OFFSET+2], 0x1234  ; Verificar firma mágica
    jne .invalid_kernel

    ; --- CARGAR EL KERNEL POR BLOQUES ---
    ; Ahora cargaremos en bloques de hasta 127 sectores (límite de BIOS)
    mov ax, KERNEL_SEGMENT
    mov es, ax
    mov bx, KERNEL_OFFSET

    ; Sector inicial
    mov word [current_sector], 3  ; Sector 3 (= LBA 2)

.load_next_block:
    ; Sectores pendientes
    mov cx, [kernel_sectors]
    cmp cx, 0
    je .loading_complete

    ; Determinar cuántos sectores cargar en esta operación
    cmp cx, MAX_SECTORS
    jbe .load_remaining
    mov cx, MAX_SECTORS        ; Cargar máximo por operación
.load_remaining:

    ; Actualizar contador de sectores pendientes
    sub [kernel_sectors], cx

    ; Cargar este bloque
    mov ah, 0x02               ; INT 13h: Read sectors
    mov al, cl                 ; Sectores a leer
    mov ch, 0                  ; Cilindro 0
    mov cl, byte [current_sector] ; Sector inicial
    mov dh, 0                  ; Cabeza 0
    mov dl, [boot_drive]       ; Unidad

    int 0x13                   ; Leer sectores
    jc disk_error

    ; Actualizar posición y dirección
    movzx ax, byte [current_sector]
    add ax, MAX_SECTORS
    mov [current_sector], ax

    ; Ajustar buffer de memoria para el siguiente bloque
    mov ax, es
    add ax, MAX_SECTORS * 512 / 16  ; 512 bytes por sector, dividido por 16 para segmentos
    mov es, ax

    ; Cargar siguiente bloque
    jmp .load_next_block

.loading_complete:
    mov si, msg_loaded
    call print_string

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

.invalid_kernel:
    mov si, msg_invalid
    call print_string
    jmp $

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

; --- DATA ---
boot_drive db 0
kernel_sectors dw 0
current_sector dw 0
msg_loading db "Cargando kernel...", 0
msg_loaded db " OK!", 0
msg_error db " Error de disco!", 0
msg_invalid db " Kernel invalido!", 0

; --- PADDING AND SIGNATURE ---
times 510-($-$$) db 0
dw 0xAA55