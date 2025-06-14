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
    
    ; --- CARGAR EL KERNEL COMPLETO ---
    mov ax, KERNEL_SEGMENT
    mov es, ax
    mov bx, KERNEL_OFFSET
    
    mov ah, 0x02            ; INT 13h: Read sectors
    mov al, cl              ; Sectores a leer (desde la cabecera)
    mov ch, 0               ; Cilindro 0
    mov cl, 3               ; Sector 3 (= LBA 2)
    mov dh, 0               ; Cabeza 0
    mov dl, [boot_drive]    ; Unidad
    
    int 0x13                ; Leer sectores
    jc disk_error
    
    ; --- DIAGNÓSTICO PRE-SALTO ---
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
msg_loading db "Cargando kernel...", 0
msg_loaded db " OK!", 0
msg_error db " Error!", 0

; --- PADDING AND SIGNATURE ---
times 510-($-$$) db 0
dw 0xAA55