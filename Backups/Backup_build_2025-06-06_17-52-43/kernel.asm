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
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    
    ; Paso 1 completado
    mov ax, 0xB800
    mov es, ax
    mov byte [es:2], '1'
    mov byte [es:3], 0x0A
    
    ; --- HABILITAR LÍNEA A20 ---
    in al, 0x92
    or al, 2
    out 0x92, al
    
    ; Paso 2 completado
    mov byte [es:4], '2'
    mov byte [es:5], 0x0A
    
    ; --- CARGAR GDT ---
    lgdt [gdt_descriptor]
    
    ; Paso 3 completado
    mov byte [es:6], '3'
    mov byte [es:7], 0x0A
    
    ; --- ENTRAR EN MODO PROTEGIDO ---
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ; Saltar a código de 32 bits (modo protegido)
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
    mov esp, 0x90000    ; Stack en 0x90000
    
    ; --- MENSAJE DE ÉXITO MODO PROTEGIDO ---
    mov dword [0xB8008], 0x0F320F33    ; "32" en atributos normales
    
    ; Limpiar parte de la pantalla (primera línea)
    mov edi, 0xB8014
    mov ecx, 16
    mov eax, 0x0F200F20  ; Espacios con atributo normal
    rep stosd
    
    ; --- LISTO PARA C ---
    mov dword [0xB8014], 0x0F430F43    ; "CC" - Listo para C
    
    ; Si se activa el punto de entrada C, llamar a kernel_main
    extern kernel_main
    call kernel_main
    
    ; Si kernel_main retorna, mostrar mensaje de finalización
    mov dword [0xB801C], 0x0F440F45    ; "ED" - End
    
    ; Bucle infinito
    cli
    hlt
    jmp $

section .data
; --- ESTRUCTURAS PARA GDT (MODO PROTEGIDO - 32 BITS) ---
align 8
gdt_start:
    ; Descriptor nulo (obligatorio)
    dq 0
    
    ; Descriptor de código (32 bits)
    dw 0xFFFF    ; Límite (bits 0-15)
    dw 0         ; Base (bits 0-15)
    db 0         ; Base (bits 16-23)
    db 0x9A      ; Acceso (presente, privilegio 0, código, ejecutable, legible)
    db 0xCF      ; Granularidad (4K) + límite (bits 16-19)
    db 0         ; Base (bits 24-31)
    
    ; Descriptor de datos (32 bits)
    dw 0xFFFF    ; Límite (bits 0-15)
    dw 0         ; Base (bits 0-15)
    db 0         ; Base (bits 16-23)
    db 0x92      ; Acceso (presente, privilegio 0, datos, escritura/lectura)
    db 0xCF      ; Granularidad (4K) + límite (bits 16-19)
    db 0         ; Base (bits 24-31)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1   ; Tamaño GDT
    dd gdt_start                 ; Dirección GDT