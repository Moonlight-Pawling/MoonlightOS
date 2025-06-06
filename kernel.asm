; ============================================
; kernel.asm con GDT corregida
; ============================================

section .early16 progbits alloc exec
[BITS 16]

global start16

start16:
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00

    lgdt [gdt_descriptor]      ; Cargar GDT

    mov eax, cr0               ; Activar modo protegido (CR0.PE = 1)
    or eax, 1
    mov cr0, eax

    ; CAMBIO: Usar selector 0x08 (segundo descriptor) para 32 bits
    jmp 0x08:start32

; ------------------------------------------------
; GDT modificada con descriptores para 32 y 64 bits
; ------------------------------------------------
gdt_start:
    dq 0                           ; [0x00] Descriptor nulo
    dq 0x00CF9A000000FFFF          ; [0x08] Código 32-bit (D=1, L=0)
    dq 0x00CF92000000FFFF          ; [0x10] Datos 32-bit
    dq 0x00AF9A000000FFFF          ; [0x18] Código 64-bit (D=0, L=1)
    dq 0x00AF92000000FFFF          ; [0x20] Datos 64-bit
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; ------------------------------------------------
; Sección 32 bits: protected mode + paginación
; ------------------------------------------------
section .pmode progbits alloc exec
[BITS 32]

global start32

start32:
    ; Cargar selectores de datos de 32 bits (0x10)
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov esp, 0x90000

    ; Configurar paginación mínima (2 MiB identity mapping)
    mov dword [0x1000], 0x2003
    mov dword [0x2000], 0x3003
    mov dword [0x3000], 0x0083

    mov eax, 0x1000
    mov cr3, eax

    ; Habilitar PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; Habilitar modo largo
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; Habilitar paginación
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    ; CAMBIO: Usar selector 0x18 (cuarto descriptor) para 64 bits
    jmp 0x18:start64

; ------------------------------------------------
; Sección 64 bits: long mode + kernel_main
; ------------------------------------------------
section .text
[BITS 64]

global start64
extern kernel_main

start64:
    ; Cargar selectores de datos de 64 bits (0x20)
    mov ax, 0x20
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    call kernel_main

.hang:
    hlt
    jmp .hang