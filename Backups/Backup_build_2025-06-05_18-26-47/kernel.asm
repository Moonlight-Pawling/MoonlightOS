; ============================================
; kernel.asm con depuración visual
; ============================================

; ------------------------------------------------
; Sección 16 bits: Real mode "stub" + GDT
; ------------------------------------------------
section .early16 progbits alloc exec
[BITS 16]

global start16

start16:
    ; Primero verificamos que llegamos aquí
    mov ax, 0xB800
    mov es, ax
    mov byte [es:0], 'A'         ; 'A' en la esquina superior izquierda
    mov byte [es:1], 0x0F        ; Color blanco sobre negro

    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Nueva GDT con entradas separadas para 32 bits y 64 bits
    lgdt [gdt_descriptor]

    ; Actualizar pantalla para mostrar que vamos a entrar a modo protegido
    mov byte [es:2], 'B'
    mov byte [es:3], 0x0F

    ; Activar modo protegido
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Salto a modo protegido usando el selector de 32 bits (0x08)
    jmp 0x08:start32

; ------------------------------------------------
; GDT revisada con descriptores específicos
; ------------------------------------------------
align 8
gdt_start:
    dq 0                           ; [0x00] Descriptor nulo
    dq 0x00CF9A000000FFFF          ; [0x08] Código 32-bit (D=1, L=0)
    dq 0x00CF92000000FFFF          ; [0x10] Datos 32-bit
    dq 0x00AF9A000000FFFF          ; [0x18] Código 64-bit (D=0, L=1)
    dq 0x00AF92000000FFFF          ; [0x20] Datos 64-bit
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1     ; Límite (tamaño - 1)
    dd gdt_start                   ; Base

; ------------------------------------------------
; Sección 32 bits: protected mode + paginación
; ------------------------------------------------
section .pmode progbits alloc exec
[BITS 32]

global start32

start32:
    ; Verificamos que llegamos al modo 32 bits
    mov ax, 0x10                   ; Selector de datos 32-bit
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Mostrar "C" para confirmar que estamos en modo 32 bits
    mov dword [0xB8000+4], 0x0F43  ; 'C' en posición 2

    ; Configurar pila para modo 32 bits
    mov esp, 0x90000

    ; Configurar paginación básica para identity mapping
    ; Primero, limpiar las tablas de página
    mov edi, 0x1000
    mov ecx, 0x1000                ; 4KB
    xor eax, eax
    rep stosd

    ; Configurar tablas de página para identidad
    mov dword [0x1000], 0x2003     ; PML4[0] → PDPT en 0x2000 (P=1, RW=1)
    mov dword [0x2000], 0x3003     ; PDPT[0] → PD en 0x3000 (P=1, RW=1)
    mov dword [0x3000], 0x0083     ; PD[0] = 2MB página con PS=1 (bit 7)

    ; Mostrar "D" para confirmar configuración de paginación
    mov dword [0xB8000+6], 0x0F44  ; 'D' en posición 3

    ; Cargar CR3 con dirección de PML4
    mov eax, 0x1000
    mov cr3, eax

    ; Habilitar PAE
    mov eax, cr4
    or eax, 1 << 5                 ; PAE bit
    mov cr4, eax

    ; Mostrar "E" para confirmar PAE habilitado
    mov dword [0xB8000+8], 0x0F45  ; 'E' en posición 4

    ; Habilitar modo largo en EFER
    mov ecx, 0xC0000080            ; EFER MSR
    rdmsr
    or eax, 1 << 8                 ; LME bit
    wrmsr

    ; Mostrar "F" para confirmar LME habilitado
    mov dword [0xB8000+10], 0x0F46 ; 'F' en posición 5

    ; Habilitar paginación
    mov eax, cr0
    or eax, 0x80000000             ; PG bit
    mov cr0, eax

    ; Mostrar "G" para confirmar paginación habilitada
    mov dword [0xB8000+12], 0x0F47 ; 'G' en posición 6

    ; Salto a modo 64 bits usando el selector correcto (0x18)
    jmp 0x18:start64

; ------------------------------------------------
; Sección 64 bits: long mode + kernel_main
; ------------------------------------------------
section .text
[BITS 64]

global start64
extern kernel_main

start64:
    ; Verificamos que llegamos al modo 64 bits
    mov ax, 0x20                   ; Selector de datos 64-bit
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Mostrar "Z" para confirmar que estamos en 64 bits
    mov rax, 0x0F5A                ; 'Z'
    mov qword [0xB8000+14], rax    ; En posición 7

    ; Configurar pila para 64 bits
    mov rsp, 0x90000

    ; Llamada a la función C
    call kernel_main

.hang:
    hlt
    jmp .hang