[BITS 16]
section .early16

global start16
start16:
    ; Verificación visual inmediata - escribir directamente a la memoria de video
    mov ax, 0xB800
    mov es, ax
    
    ; Escribir "*OK*" en atributos brillantes
    mov byte [es:0], '*'
    mov byte [es:1], 0x0F
    mov byte [es:2], 'O'
    mov byte [es:3], 0x0A
    mov byte [es:4], 'K'
    mov byte [es:5], 0x0A
    mov byte [es:6], '*'
    mov byte [es:7], 0x0F
    
    ; Bucle infinito - no hacer nada más por ahora
    cli
    hlt
    jmp $