; ============================================
; kernel.asm:
;   - Sección .early16: real-mode (16 bits) + GDT + salto a protected mode
;   - Sección .pmode : protected mode (32 bits) + paginación mínima
;   - Sección .text  : long mode (64 bits) + llamada a kernel_main (C)
; ============================================

; ------------------------------------------------
; Sección 16 bits: Real mode “stub” + GDT
; ------------------------------------------------
section .early16 progbits alloc exec
[BITS 16]

global start16                  ; Punto de entrada para el linker
extern start32                  ; Definido luego en la sección 32 bits

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

    jmp 0x08:start32           ; Salto a modo protegido (selector = 0x08)

; ------------------------------------------------
; GDT (justo debajo, para estar < 64 KiB)
; ------------------------------------------------
gdt_start:
    dq 0                           ; Descriptor nulo
    dq 0x00AF9A000000FFFF          ; Código: ejecutable + 64 bit (L=1)
    dq 0x00AF92000000FFFF          ; Datos: lectura/escritura
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; ------------------------------------------------
; Sección 32 bits: protected mode + paginación
; ------------------------------------------------
section .pmode progbits alloc exec
[BITS 32]

global start32                  ; Definido aquí
extern start64                  ; Para salto a 64 bits

start32:
    ; Cargar selectores de datos con 0x10
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov esp, 0x90000            ; Pila temporal en 0x90000

    ; ------------------------
    ; Configurar paginación mínima (2 MiB identity mapping)
    ; ------------------------
    mov dword [0x1000], 0x2003   ; PML4[0] → PDPT en 0x2000 (P=1, RW=1)
    mov dword [0x2000], 0x3003   ; PDPT[0] → PD en 0x3000 (P=1, RW=1)
    mov dword [0x3000], 0x0083   ; PD[0] mapea 2 MiB @ 0x0 (P=1, RW=1, PS=1)

    mov eax, 0x1000
    mov cr3, eax                 ; Cargar base de PML4

    ; Habilitar PAE (CR4.PAE = 1)
    mov eax, cr4
    or eax, 1 << 5               ; bit 5 = PAE
    mov cr4, eax

    ; Habilitar modo largo (EFER.LME = 1)
    mov ecx, 0xC0000080          ; MSR IA32_EFER
    rdmsr
    or eax, 1 << 8               ; bit 8 = LME
    wrmsr

    ; Habilitar paginación (CR0.PG = 1)
    mov eax, cr0
    or eax, 0x80000000           ; bit 31 = PG
    mov cr0, eax

    jmp 0x08:start64             ; Salto a 64 bits (selector = 0x08)

; ------------------------------------------------
; Sección 64 bits: long mode + kernel_main
; ------------------------------------------------
section .text
[BITS 64]

global start64                   ; Definido aquí
extern kernel_main               ; Función en kernel.c

start64:
    ; En long mode los segmentos de datos se ignoran, pero cargamos igual
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    call kernel_main            ; Llamada final a la función en C

.hang:
    hlt
    jmp .hang
