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
    mov ch, 0
    mov cl, 3
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    ; --- OBTENER TAMAÑO DEL KERNEL (ahora 4 bytes) ---
    mov si, KERNEL_OFFSET
    mov eax, [ds:si]        ; Lee 4 bytes del tamaño
    cmp eax, 0
    jne .size_ok
    mov eax, 32
.size_ok:
    mov [kernel_sectors], eax

    ; --- VERIFICAR FIRMA MÁGICA ---
    mov cx, [KERNEL_OFFSET+4]
    cmp cx, 0x1234
    jne .invalid_kernel

    ; --- CARGAR EL KERNEL POR BLOQUES ---
    mov ax, KERNEL_SEGMENT
    mov es, ax
    mov bx, KERNEL_OFFSET
    mov dword [current_sector], 3

.load_next_block:
    mov eax, [kernel_sectors]
    cmp eax, 0
    je .loading_complete

    mov ecx, eax
    cmp ecx, 127
    jbe .load_remaining
    mov ecx, 127
.load_remaining:
    sub dword [kernel_sectors], ecx

    mov ah, 0x02
    mov al, cl
    mov ch, 0
    mov cl, byte [current_sector]
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc disk_error

    add dword [current_sector], ecx
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
kernel_sectors dd 0      ; <--- Cambiado a dword
current_sector dd 0      ; <--- Cambiado a dword
msg_loading db "MoonlightOS: Iniciando carga del Portal (64-bit)...", 0
msg_loaded db " Portal cargado correctamente en memoria!", 0
msg_error db " Error: Fallo al leer sectores del disco", 0
msg_invalid db " Error: El Portal no es valido o esta corrupto (firma incorrecta)", 0

; --- PADDING AND SIGNATURE ---
times 510-($-$$) db 0
dw 0xAA55