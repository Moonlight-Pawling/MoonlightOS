[BITS 16]              ; Código en modo real (16 bits) al inicio
[ORG 0x8000]          ; Dirección donde el bootloader carga el kernel (segmento 0, offset 0x8000)

start:
    cli                 ; Deshabilitar interrupciones para evitar problemas mientras configuramos
    xor ax, ax
    mov ds, ax          ; DS = 0, segmento datos 0x0000
    mov ss, ax          ; SS = 0, segmento stack 0x0000
    mov sp, 0x7C00      ; SP = 0x7C00, stack en 0x0000:0x7C00

    ; -------------------
    ; Cargar la GDT en memoria
    ; -------------------

    lgdt [gdt_descriptor]  ; Carga la dirección y tamaño de la GDT (tabla de segmentos) en el registro GDTR

    ; -------------------
    ; Activar modo protegido
    ; -------------------

    mov eax, cr0          ; Leer registro de control CR0
    or eax, 1             ; Poner bit 0 (PE, Protection Enable) en 1 para habilitar modo protegido
    mov cr0, eax          ; Guardar nuevamente en CR0 para activar modo protegido

    ; -------------------
    ; Salto a modo protegido: cambio de segmento y modo de 16 a 32 bits
    ; -------------------

    ; Far jump para limpiar prefetch pipeline y cargar CS nuevo
    jmp 0x08:protected_mode_start

; -------------------
; GDT (Global Descriptor Table)
; -------------------

gdt_start:
    ; Descriptor nulo (obligatorio)
    dd 0x00000000
    dd 0x00000000

    ; Descriptor código 32 bits (base=0, límite=4GB, ejecutable, lectura)
    dd 0x0000FFFF       ; Límite bajo (16 bits) y base bajo (16 bits)
    dd 0x00CF9A00       ; Base medio (8 bits), acceso, flags y límite alto (4 bits)

    ; Descriptor datos 32 bits (base=0, límite=4GB, lectura/escritura)
    dd 0x0000FFFF
    dd 0x00CF9200

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1   ; Tamaño de la GDT (en bytes menos 1)
    dd gdt_start                 ; Dirección base de la GDT

; -------------------
; Código modo protegido 32 bits
; -------------------

[BITS 32]
protected_mode_start:
    ; Actualizar registros de segmento con selectores GDT
    mov ax, 0x10           ; Selector segmento datos (índice 2 en GDT)
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Configurar stack para modo protegido
    mov esp, 0x90000       ; Stack pointer (ESP) en memoria 32 bits (ajustar según memoria)

    ; -------------------
    ; Activar modo largo (64 bits) mediante paginación y EFER
    ; -------------------

    ; Configurar paging (PML4, PDPT, PD, PT) para 64 bits - muy simplificado aquí,
    ; lo ideal es hacerlo en C o con más detalles, pero para ejemplo dejamos esto

    ; Activar Long Mode
    mov ecx, 0xC0000080    ; MSR EFER (Extended Feature Enable Register)
    rdmsr                  ; Leer MSR EFER (en EDX:EAX)
    or eax, 0x00000100     ; Poner bit LME (Long Mode Enable)
    wrmsr                  ; Escribir de nuevo MSR EFER

    ; Activar paginación
    mov eax, cr4
    or eax, 0x00000020     ; Poner bit PAE (Physical Address Extension)
    mov cr4, eax

    mov eax, cr0
    or eax, 0x80000000     ; Poner bit PG (Paging enable)
    mov cr0, eax

    ; Ahora estamos en modo largo, hacemos salto a código 64 bits
    jmp 0x08:long_mode_start

; -------------------
; Código 64 bits (modo largo)
; -------------------   
    
    extern kernel_main

[BITS 64]
long_mode_start:
    ; Aquí ya puedes poner código en 64 bits, por ejemplo:
    mov ax, 0x10          ; Cargar selector segmento datos
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Llamada a kernel_main en C
    call kernel_main
    ; Si kernel_main regresa, entra a loop infinito

.loop:
    hlt
    jmp .loop
