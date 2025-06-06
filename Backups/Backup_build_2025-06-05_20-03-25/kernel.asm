; ============================================
; kernel.asm con depuración visual extensa
; ============================================

section .early16 progbits alloc exec
[BITS 16]

global start16

start16:
    ; ---- MODO REAL (16 bits) ----
    ; Escribir mensaje de inicio en modo real
    mov ax, 0xB800
    mov es, ax
    mov byte [es:0], 'R'        ; 'R' = Modo Real
    mov byte [es:1], 0x0F       ; Blanco sobre negro
    mov byte [es:2], '-'
    mov byte [es:3], 0x0F
    mov byte [es:4], '1'        ; Fase 1
    mov byte [es:5], 0x0F
    
    ; Configuración básica
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Actualizar pantalla - Etapa 2
    mov ax, 0xB800
    mov es, ax
    mov byte [es:6], '-'
    mov byte [es:7], 0x0F
    mov byte [es:8], '2'        ; Fase 2
    mov byte [es:9], 0x0F

    ; Cargar GDT
    lgdt [gdt_descriptor]
    
    ; Actualizar pantalla - Antes de modo protegido
    mov byte [es:10], '-'
    mov byte [es:11], 0x0F
    mov byte [es:12], 'G'       ; GDT cargada
    mov byte [es:13], 0x0F
    
    ; Activar A20
    in al, 0x92
    or al, 2
    out 0x92, al
    
    ; Activar modo protegido
    mov eax, cr0
    or eax, 1                ; PE bit
    mov cr0, eax

    ; Salto a modo protegido
    jmp 0x08:protected_mode

; ---- GDT para transición a 32 y 64 bits ----
align 8
gdt_start:
    ; Descriptor nulo (índice 0)
    dq 0                           
    
    ; Código 32 bits (índice 1, selector 0x08)
    dw 0xFFFF       ; Límite [0:15]
    dw 0x0000       ; Base [0:15]
    db 0x00         ; Base [16:23]
    db 10011010b    ; P=1, DPL=00, S=1, Type=1010
    db 11001111b    ; G=1, D/B=1, L=0, Límite [16:19]
    db 0x00         ; Base [24:31]
    
    ; Datos 32/64 bits (índice 2, selector 0x10)
    dw 0xFFFF       ; Límite [0:15]
    dw 0x0000       ; Base [0:15]
    db 0x00         ; Base [16:23]
    db 10010010b    ; P=1, DPL=00, S=1, Type=0010
    db 11001111b    ; G=1, D/B=1, L=0, Límite [16:19]
    db 0x00         ; Base [24:31]
    
    ; Código 64 bits (índice 3, selector 0x18)
    dw 0xFFFF       ; Límite [0:15]
    dw 0x0000       ; Base [0:15]
    db 0x00         ; Base [16:23]
    db 10011010b    ; P=1, DPL=00, S=1, Type=1010
    db 10101111b    ; G=1, D/B=0, L=1, Límite [16:19]
    db 0x00         ; Base [24:31]
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1   ; Límite
    dd gdt_start                 ; Base

; ------------------------------------------------
; Sección 32 bits: protected mode + paginación
; ------------------------------------------------
section .pmode progbits alloc exec
[BITS 32]

protected_mode:
    ; ---- MODO PROTEGIDO (32 bits) ----
    ; Cargar selectores de datos
    mov ax, 0x10                 ; Selector de datos
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Marcador visual - Modo protegido
    mov dword [0xB8000], 0x0F50  ; 'P'
    mov dword [0xB8002], 0x0F2D  ; '-'
    mov dword [0xB8004], 0x0F31  ; '1'
    
    ; Configurar stack
    mov esp, 0x90000
    
    ; Limpiar tablas de página - 3 páginas de 4KB
    mov dword [0xB8006], 0x0F2D  ; '-'
    mov dword [0xB8008], 0x0F32  ; '2'
    
    mov edi, 0x1000
    xor eax, eax
    mov ecx, 0x3000      ; 12KB (3 pages * 4KB)
    rep stosd            ; Llenar con ceros
    
    ; Marcador visual - Tablas limpias
    mov dword [0xB800A], 0x0F2D  ; '-'
    mov dword [0xB800C], 0x0F33  ; '3'
    
    ; Configurar tablas de paginación
    mov dword [0x1000], 0x2003   ; PML4[0] → PDPT
    mov dword [0x2000], 0x3003   ; PDPT[0] → PD
    mov dword [0x3000], 0x0083   ; PD[0] → 2MB página (PS=1)
    
    ; Marcador visual - Tablas configuradas
    mov dword [0xB800E], 0x0F2D  ; '-'
    mov dword [0xB8010], 0x0F34  ; '4'
    
    ; Cargar CR3 con PML4
    mov eax, 0x1000
    mov cr3, eax
    
    ; Marcador visual - CR3 cargado
    mov dword [0xB8012], 0x0F2D  ; '-'
    mov dword [0xB8014], 0x0F35  ; '5'
    
    ; Habilitar PAE
    mov eax, cr4
    or eax, 1 << 5       ; PAE (bit 5)
    mov cr4, eax
    
    ; Marcador visual - PAE habilitado
    mov dword [0xB8016], 0x0F2D  ; '-'
    mov dword [0xB8018], 0x0F36  ; '6'
    
    ; Habilitar modo largo (LME)
    mov ecx, 0xC0000080  ; EFER MSR
    rdmsr
    or eax, 1 << 8       ; LME (bit 8)
    wrmsr
    
    ; Marcador visual - LME habilitado
    mov dword [0xB801A], 0x0F2D  ; '-'
    mov dword [0xB801C], 0x0F37  ; '7'
    
    ; Habilitar paginación
    mov eax, cr0
    or eax, 0x80000000   ; PG (bit 31)
    mov cr0, eax
    
    ; Marcador visual - Paginación habilitada
    mov dword [0xB801E], 0x0F2D  ; '-'
    mov dword [0xB8020], 0x0F38  ; '8'
    
    ; Salto a modo 64 bits
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
    mov ax, 0x10         ; Selector de datos
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Marcador visual - Modo 64 bits
    mov dword [0xB8022], 0x0F2D  ; '-'
    mov dword [0xB8024], 0x0F4C  ; 'L'
    
    ; Establecer stack de 64 bits
    mov rsp, 0x90000
    
    ; Marcador visual - Antes de kernel_main
    mov dword [0xB8026], 0x0F2D  ; '-'
    mov dword [0xB8028], 0x0F43  ; 'C'
    
    ; Llamar a kernel_main
    call kernel_main

    ; No deberíamos volver, pero por si acaso
.hang:
    ; Marcador visual - Volvimos de kernel_main
    mov dword [0xB802A], 0x0F2D  ; '-'
    mov dword [0xB802C], 0x0F58  ; 'X'
    
    hlt
    jmp .hang