; ============================================
; kernel.asm:
;   - Sección .early16: real-mode + GDT + salto a modo protegido
;   - Sección .pmode : modo protegido + configuración de paginación
;   - Sección .text  : modo largo + llamada a kernel_main (C)
; ============================================

; ------------------------------------------------
;  Sección 16 bits: real mode “stub” + GDT
; ------------------------------------------------
section .early16 progbits alloc exec
[BITS 16]

global start                   ; Punto de entrada para el linker
extern pmode_entry             ; Definido luego en la sección 32 bits

start:
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00

    lgdt [gdt_descriptor]      ; Cargar GDT (definida abajo)

    mov eax, cr0               ; Activar modo protegido (CR0.PE = 1)
    or eax, 1
    mov cr0, eax

    jmp 0x08:pmode_entry       ; Salto a modo protegido (selector = 0x08)

; ------------------------
; GDT (directamente tras el stub, para estar < 64 KiB)
; ------------------------
gdt_start:
    dq 0                           ; Descriptor nulo
    dq 0x00AF9A000000FFFF          ; Código: ejecutable + 64-bit (L=1)
    dq 0x00AF92000000FFFF          ; Datos: lectura/escritura
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; ------------------------------------------------
;  Sección 32 bits: modo protegido + paginación
; ------------------------------------------------
section .pmode progbits alloc exec
[BITS 32]

global pmode_entry             ; Definimos aquí
extern lmode_entry             ; Para salto a 64 bits

pmode_entry:
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
    mov dword [0x1000], 0x2003   ; PML4[0] apunta a PDPT en 0x2000 | P=1 | RW=1
    mov dword [0x2000], 0x3003   ; PDPT[0] apunta a PD en 0x3000 | P=1 | RW=1
    mov dword [0x3000], 0x0083   ; PD[0] mapea 2MiB en 0x0 con P=1 | RW=1 | PS=1

    mov eax, 0x1000
    mov cr3, eax                 ; Cargar base de PML4 en CR3

    ; Habilitar PAE (CR4.PAE = 1)
    mov eax, cr4
    or eax, 1 << 5               ; bit 5 = PAE
    mov cr4, eax

    ; Habilitar modo largo en EFER (EFER.LME = 1)
    mov ecx, 0xC0000080          ; MSR IA32_EFER
    rdmsr
    or eax, 1 << 8               ; bit 8 = LME
    wrmsr

    ; Habilitar paginación (CR0.PG = 1)
    mov eax, cr0
    or eax, 0x80000000           ; bit 31 = PG
    mov cr0, eax

    jmp 0x08:lmode_entry         ; Salto a modo largo (selector = 0x08)

; ------------------------------------------------
;  Sección 64 bits: modo largo + kernel_main
; ------------------------------------------------
section .text
[BITS 64]

global lmode_entry              ; Punto de entrada en 64 bits
extern kernel_main              ; Función C a la que saltamos

lmode_entry:
    ; En modo largo, los segmentos de datos se ignoran, pero se cargan igual
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    call kernel_main            ; Llamada final a la rutina en C

.hang:
    hlt
    jmp .hang
