section .early16 progbits alloc exec
[BITS 16]

global start16

start16:
    ; Código muy básico para mostrar algo en pantalla 
    ; y no hacer transición de modos aún
    mov ax, 0xB800
    mov es, ax
    mov byte [es:0], 'X'
    mov byte [es:1], 0x0F
    
    jmp $  ; Bucle infinito para verificar si llegamos aquí

; Agrega un GDT mínimo por si acaso
gdt_start:
    dq 0
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start