[BITS 16]
section .early16

global start16
start16:
    ; Verificación visual inicial
    mov ax, 0xB800
    mov es, ax
    mov byte [es:0], '*'
    mov byte [es:1], 0x0F
    
    ; --- PREPARACIÓN PARA MODO PROTEGIDO ---
    cli                     ; Deshabilitar interrupciones
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    
    ; Actualizar pantalla: paso 1 completado
    mov ax, 0xB800
    mov es, ax
    mov byte [es:2], '1'
    mov byte [es:3], 0x0A
    
    ; --- HABILITAR LÍNEA A20 ---
    in al, 0x92
    or al, 2
    out 0x92, al
    
    ; Actualizar pantalla: paso 2 completado
    mov byte [es:4], '2'
    mov byte [es:5], 0x0A
    
    ; --- CARGAR GDT ---
    lgdt [gdt_descriptor]
    
    ; Actualizar pantalla: paso 3 completado
    mov byte [es:6], '3'
    mov byte [es:7], 0x0A
    
    ; --- ENTRAR EN MODO PROTEGIDO ---
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ; Saltar a código de 32 bits
    jmp 0x08:protected_mode

[BITS 32]
protected_mode:
    ; --- INICIALIZACIÓN DE MODO PROTEGIDO ---
    mov ax, 0x10    ; Selector de datos
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000    ; Nuevo stack
    
    ; --- MENSAJE DE ÉXITO MODO PROTEGIDO ---
    ; Escribir "32" en modo protegido
    mov dword [0xB8008], 0x0F320F33    ; "32" en atributos normales
    
    ; Bucle infinito - por ahora
    jmp $

section .data
; --- ESTRUCTURAS PARA MODO PROTEGIDO ---
align 8
gdt_start:
    ; Descriptor nulo
    dq 0
    
    ; Descriptor de código (32 bits)
    dw 0xFFFF    ; Límite (bits 0-15)
    dw 0         ; Base (bits 0-15)
    db 0         ; Base (bits 16-23)
    db 0x9A      ; Acceso (presente, privilegio 0, tipo código, ejecutable, readable)
    db 0xCF      ; Granularidad (4K páginas) + límite (bits 16-19)
    db 0         ; Base (bits 24-31)
    
    ; Descriptor de datos (32 bits)
    dw 0xFFFF    ; Límite (bits 0-15)
    dw 0         ; Base (bits 0-15)
    db 0         ; Base (bits 16-23)
    db 0x92      ; Acceso (presente, privilegio 0, tipo datos, writable)
    db 0xCF      ; Granularidad (páginas de 4K) + límite (bits 16-19)
    db 0         ; Base (bits 24-31)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1   ; Tamaño GDT
    dd gdt_start                 ; Dirección GDT