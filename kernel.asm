[BITS 16]
section .early16

global start16
start16:
    ; Diagnóstico visual inicial
    mov ax, 0xB800
    mov es, ax
    mov byte [es:0], '*'
    mov byte [es:1], 0x0F

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

    ; Habilitar A20
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Paso 2 completado
    mov byte [es:4], '2'
    mov byte [es:5], 0x0A

    ; Cargar GDT protegida
    lgdt [gdt_descriptor]
    mov byte [es:6], '3'
    mov byte [es:7], 0x0A

    ; Entrar a modo protegido
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_mode

; --- PROTECTED MODE ---
[BITS 32]
protected_mode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov esp, 0x90000

    mov dword [0xB8008], 0x0F4D0F33 ; "M3"

    ; ----- Habilitar PAE -----
    mov eax, cr4
    or eax, 1 << 5         ; Set PAE
    mov cr4, eax

    mov dword [0xB800C], 0x0F505041 ; "PA"

    ; ----- Configurar tablas de paginación simplificadas -----
    ; PML4, PDPT, PD - identidad primeros 1GB
    lea eax, [pml4]
    mov cr3, eax

    ; ----- Habilitar Long Mode (EFER.LME) -----
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8         ; EFER.LME
    wrmsr

    mov dword [0xB8010], 0x0F4C0F4C ; "LL"

    ; ----- Habilitar paginación -----
    mov eax, cr0
    or eax, 0x80000001     ; PG y PE
    mov cr0, eax

    mov ax, 0xB800
    mov es, ax
    mov byte [es:0], 'P'
    mov byte [es:1], 0x0C

    ; Saltar a modo largo: far jump a código 64 bits
    jmp 0x28:long_mode_start

; --- LONG MODE (64 bits) ---
[BITS 64]
long_mode_start:
    mov ax, 0x30
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov rsp, 0x90000

    mov dword [0xB8018], 0x0F360F36
    mov dword [0xB801C], 0x0F360F36

    extern kernel_main
    call kernel_main

.hang:
    hlt
    jmp .hang

section .data
align 8
gdt_start:
    dq 0                        ; NULL
    dq 0x00CF9A000000FFFF       ; 0x08: Código 32b
    dq 0x00CF92000000FFFF       ; 0x10: Datos 32b
    dq 0x00AF9A000000FFFF       ; 0x18: Código 64b
    dq 0x00AF92000000FFFF       ; 0x20: Datos 64b
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dq gdt_start

; --- Tablas de paginación mínimas para modo largo (identidad 1GB) ---
align 4096
pml4:
    dq pdpt + 0x03
    times 511 dq 0

align 4096
pdpt:
    dq pd + 0x03
    times 511 dq 0

align 4096
pd:
    %assign i 0
    %rep 512
        dq (i << 21) + 0x83
        %assign i i+1
    %endrep

section .bss