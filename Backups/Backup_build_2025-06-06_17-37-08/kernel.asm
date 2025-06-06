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
    mov dword [0xB8008], 0x0F320F33    ; "32" en atributos normales
    
    ; --- CONFIGURAR PAGINACIÓN ---
    ; Inicializar tablas de página a cero
    mov edi, 0x100000           ; Dirección para tablas (1MB)
    mov cr3, edi                ; Establecer CR3 a la dirección base
    xor eax, eax
    mov ecx, 4096 * 4           ; 4 páginas de 4K = 16K para tablas
    rep stosd                   ; Poner ceros
    
    ; Configurar tablas de página
    mov edi, 0x100000           ; PML4
    mov dword [edi], 0x101003   ; Bit presente, escritura, apunta a PDPT
    
    mov edi, 0x101000           ; PDPT
    mov dword [edi], 0x102003   ; Bit presente, escritura, apunta a PD
    
    mov edi, 0x102000           ; PD
    mov dword [edi], 0x103003   ; Bit presente, escritura, apunta a PT
    
    ; Mapear primeros 2MB de memoria (identidad)
    mov edi, 0x103000           ; PT
    mov ebx, 0                  ; Dirección física inicial
    mov ecx, 512                ; 512 entradas = 2MB
.map_pt:
    mov dword [edi], ebx
    or dword [edi], 3           ; Bit presente, escritura
    add ebx, 0x1000             ; Siguiente página física
    add edi, 8                  ; Siguiente entrada (8 bytes en 64 bits)
    loop .map_pt
    
    ; Actualizar indicador de progreso
    mov dword [0xB800C], 0x0F500F34    ; "4P" (Paginación configurada)
    
    ; --- ACTIVAR MODO LARGO ---
    ; Habilitar PAE
    mov eax, cr4
    or eax, (1 << 5)            ; PAE bit
    mov cr4, eax
    
    ; Activar bit de modo largo en EFER
    mov ecx, 0xC0000080         ; EFER MSR
    rdmsr
    or eax, (1 << 8)            ; LME bit
    wrmsr
    
    ; Activar paginación
    mov eax, cr0
    or eax, (1 << 31)           ; PG bit
    mov cr0, eax
    
    ; Actualizar indicador de progreso 
    mov dword [0xB8010], 0x0F4C0F35    ; "5L" (Modo largo habilitado)
    
    ; Saltar a código de 64 bits
    jmp 0x08:long_mode

[BITS 64]
long_mode:
    ; --- INICIALIZACIÓN DE MODO LARGO ---
    ; Actualizar selectores de segmento
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Mostrar mensaje de éxito 64 bits
    mov dword [0xB8014], 0x0F340F36    ; "64"
    
    ; Bucle infinito por ahora
    jmp $

section .data
; --- ESTRUCTURAS PARA GDT ---
align 8
gdt_start:
    ; Descriptor nulo
    dq 0
    
    ; Descriptor de código - 64 bit
    dw 0xFFFF    ; Límite (bits 0-15)
    dw 0         ; Base (bits 0-15) 
    db 0         ; Base (bits 16-23)
    db 0x9A      ; Acceso (presente, privilegio 0, ejecutable, readable)
    db 0xAF      ; Granularidad (4K) + modo largo + límite (bits 16-19)
    db 0         ; Base (bits 24-31)
    
    ; Descriptor de datos - 64 bit
    dw 0xFFFF    ; Límite (bits 0-15)
    dw 0         ; Base (bits 0-15)
    db 0         ; Base (bits 16-23)
    db 0x92      ; Acceso (presente, privilegio 0, datos, writable)
    db 0xCF      ; Granularidad (4K) + límite (bits 16-19)
    db 0         ; Base (bits 24-31)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1   ; Tamaño GDT
    dd gdt_start                 ; Dirección GDT