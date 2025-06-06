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
    
    ; Pausa diagnóstica - asegurar que vemos "32" antes de continuar
    mov ecx, 0x1000000
.pause:
    nop
    loop .pause
    
    ; --- CONFIGURAR PAGINACIÓN ---
    ; Limpiar área para tablas de página 
    mov edi, page_tables     ; Área de tablas ya definida en .bss
    xor eax, eax
    mov ecx, 4096           ; 4K (suficiente para tablas iniciales)
    rep stosd
    
    ; Actualizar indicador - iniciando paginación
    mov dword [0xB800C], 0x0F490F34    ; "4I" (Iniciando paginación)
    
    ; Punteros básicos para tablas anidadas
    mov eax, page_tables
    mov cr3, eax            ; Establecer dirección base de tablas
    
    mov eax, page_tables 
    add eax, 0x1000
    or eax, 3               ; Presente (1) + Escritura (2)
    mov [page_tables], eax  ; PML4[0] -> PDPT
    
    mov eax, page_tables
    add eax, 0x2000
    or eax, 3               ; Presente (1) + Escritura (2)
    mov [page_tables + 0x1000], eax ; PDPT[0] -> PD
    
    mov eax, page_tables
    add eax, 0x3000
    or eax, 3               ; Presente (1) + Escritura (2)
    mov [page_tables + 0x2000], eax ; PD[0] -> PT
    
    ; Mapear primera página (identidad)
    mov dword [page_tables + 0x3000], 3    ; PT[0] -> 0x0 (presente + escritura)
    
    ; Actualizar indicador - paginación configurada
    mov dword [0xB800C], 0x0F500F34    ; "4P" (Paginación configurada)
    
    ; --- ACTIVAR MODO LARGO ---
    ; Habilitar PAE
    mov eax, cr4
    or eax, (1 << 5)            ; PAE bit
    mov cr4, eax
    
    ; Actualizar indicador - PAE habilitado
    mov dword [0xB8010], 0x0F410F35    ; "5A" (PAE activado)
    
    ; Activar bit de modo largo en EFER
    mov ecx, 0xC0000080         ; EFER MSR
    rdmsr
    or eax, (1 << 8)            ; LME bit
    wrmsr
    
    ; Actualizar indicador - LME habilitado
    mov dword [0xB8010], 0x0F4C0F35    ; "5L" (LME activado)
    
    ; Activar paginación
    mov eax, cr0
    or eax, (1 << 31)           ; PG bit
    mov cr0, eax
    
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
    cli
    hlt
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

; --- ÁREA PARA TABLAS DE PÁGINA ---
section .bss
align 4096
page_tables:
    resb 4096 * 4    ; Reservar espacio para 4 tablas de página de 4K cada una