; ============================================
; kernel.asm: Con marcadores de estado más claros
; ============================================

section .early16 progbits alloc exec
[BITS 16]

global start16

start16:
    ; ---- MODO REAL (16 bits) ----
    ; Escribir directamente en la memoria de video para confirmar ejecución
    mov ax, 0xB800
    mov es, ax
    mov word [es:0], 0x074B  ; 'K' en gris
    mov word [es:2], 0x0731  ; '1' en gris
    
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Cargar nuestra GDT
    lgdt [gdt_descriptor]
    
    ; Indicador visual antes de cambio de modo
    mov word [es:4], 0x0732  ; '2' en gris

    ; Activar modo protegido
    mov eax, cr0
    or eax, 1                ; Activar PE (bit 0)
    mov cr0, eax

    ; Salto a modo protegido
    jmp 0x08:protected_mode

; GDT clara, con un descriptor para 32 bits y otro para 64 bits
align 8
gdt_start:
    ; Descriptor nulo (índice 0)
    dq 0                           
    
    ; Descriptor de código 32 bits (índice 1, selector 0x08)
    ; Base=0, Límite=0xFFFFF, Presente, DPL=0, Ejecutable, Readable, 32-bit
    dw 0xFFFF       ; Límite [0:15]
    dw 0x0000       ; Base [0:15]
    db 0x00         ; Base [16:23]
    db 10011010b    ; P=1, DPL=00, S=1, Type=1010 (código lectura/ejecución)
    db 11001111b    ; G=1, D/B=1, L=0, Límite [16:19]=1111
    db 0x00         ; Base [24:31]
    
    ; Descriptor de datos 32 bits (índice 2, selector 0x10)
    dw 0xFFFF       ; Límite [0:15]
    dw 0x0000       ; Base [0:15]
    db 0x00         ; Base [16:23]
    db 10010010b    ; P=1, DPL=00, S=1, Type=0010 (datos lectura/escritura)
    db 11001111b    ; G=1, D/B=1, L=0, Límite [16:19]=1111
    db 0x00         ; Base [24:31]
    
    ; Descriptor de código 64 bits (índice 3, selector 0x18)
    dw 0xFFFF       ; Límite [0:15]
    dw 0x0000       ; Base [0:15]
    db 0x00         ; Base [16:23]
    db 10011010b    ; P=1, DPL=00, S=1, Type=1010 (código lectura/ejecución)
    db 10101111b    ; G=1, D/B=0, L=1, Límite [16:19]=1111
    db 0x00         ; Base [24:31]
    
    ; Descriptor de datos 64 bits (índice 4, selector 0x20)
    dw 0xFFFF       ; Límite [0:15]
    dw 0x0000       ; Base [0:15]
    db 0x00         ; Base [16:23]
    db 10010010b    ; P=1, DPL=00, S=1, Type=0010 (datos lectura/escritura)
    db 10101111b    ; G=1, D/B=0, L=1, Límite [16:19]=1111
    db 0x00         ; Base [24:31]
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1   ; Límite (tamaño - 1)
    dd gdt_start                 ; Base de la GDT

; ------------------------------------------------
; Sección 32 bits: protected mode + paginación
; ------------------------------------------------
section .pmode progbits alloc exec
[BITS 32]

global start32

protected_mode:
    ; ---- MODO PROTEGIDO (32 bits) ----
    ; Cargar selectores de datos
    mov ax, 0x10                 ; Selector de datos (índice 2)
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Indicador visual de modo protegido
    mov dword [0xB8000+6], 0x0733  ; '3' en gris
    
    ; Configurar stack
    mov esp, 0x90000
    
    ; Limpiar las tablas de página primero
    mov edi, 0x1000
    xor eax, eax
    mov ecx, 0x1000      ; 4KB
    rep stosd            ; Llenar con ceros (4 bytes a la vez)
    
    ; Indicador visual después de limpiar
    mov dword [0xB8000+8], 0x0734  ; '4' en gris
    
    ; Configurar estructuras de paginación de 64 bits
    mov dword [0x1000], 0x2003   ; PML4[0] → PDPT
    mov dword [0x2000], 0x3003   ; PDPT[0] → PD
    mov dword [0x3000], 0x0083   ; PD[0] → 2MB página (PS=1)
    
    ; Indicador visual después de configurar tablas
    mov dword [0xB8000+10], 0x0735  ; '5' en gris
    
    ; Cargar CR3 con PML4
    mov eax, 0x1000
    mov cr3, eax
    
    ; Habilitar PAE
    mov eax, cr4
    or eax, 1 << 5       ; PAE (bit 5)
    mov cr4, eax
    
    ; Indicador visual después de PAE
    mov dword [0xB8000+12], 0x0736  ; '6' en gris
    
    ; Habilitar modo largo
    mov ecx, 0xC0000080  ; EFER MSR
    rdmsr
    or eax, 1 << 8       ; LME (bit 8)
    wrmsr
    
    ; Indicador visual después de habilitar EFER.LME
    mov dword [0xB8000+14], 0x0737  ; '7' en gris
    
    ; Habilitar paginación
    mov eax, cr0
    or eax, 0x80000000   ; PG (bit 31)
    mov cr0, eax
    
    ; Indicador visual antes del salto a 64 bits
    mov dword [0xB8000+16], 0x0738  ; '8' en gris
    
    ; Salto a modo 64 bits (usando el selector 0x18)
    jmp 0x18:long_mode

; ------------------------------------------------
; Sección 64 bits: long mode + kernel_main
; ------------------------------------------------
section .text
[BITS 64]

global start64
extern kernel_main

long_mode:
    ; ---- MODO LARGO (64 bits) ----
    ; Cargar selectores de segmento de datos
    mov ax, 0x20         ; Selector de datos 64 bits
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Indicador visual de que llegamos a 64 bits
    mov dword [0xB8000+18], 0x0739  ; '9' en gris
    mov dword [0xB8000+20], 0x0764  ; 'd' en gris
    
    ; Establecer stack de 64 bits
    mov rsp, 0x90000
    
    ; Indicador visual antes de saltar a C
    mov dword [0xB8000+22], 0x0743  ; 'C' en gris
    
    ; Llamar a nuestra función C
    call kernel_main

    ; No deberíamos regresar, pero por si acaso
.hang:
    hlt
    jmp .hang