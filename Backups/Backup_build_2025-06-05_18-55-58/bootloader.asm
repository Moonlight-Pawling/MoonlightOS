[BITS 16]
[ORG 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov byte [boot_drive], dl   ; Guardar unidad de arranque

    ; --- Mostrar mensaje inicial ---
    mov si, msg_loading
.print_char:
    lodsb
    or al, al
    jz .load_kernel
    mov ah, 0x0E
    int 0x10
    jmp .print_char

.load_kernel:
    ; --- Cargar kernel en partes de 127 sectores cada una ---
    mov ax, 0                    ; Segmento ES = 0
    mov es, ax
    mov bx, 0x8000               ; Offset inicial
    
    ; Primera carga (127 sectores o menos)
    mov ah, 0x02                 ; Función de lectura
    mov al, 127                  ; Máximo 127 sectores por operación
    cmp al, KERNEL_SECTORS       ; Si KERNEL_SECTORS < 127, usar ese valor
    jb .small_kernel
    mov cx, KERNEL_SECTORS       ; Guardar total para bucle
    jmp .first_load
.small_kernel:
    mov al, KERNEL_SECTORS
    mov cx, 0                    ; No necesitamos más cargas
.first_load:
    mov ch, 0                    ; Cilindro 0
    mov cl, 2                    ; Empezar en el sector 2
    mov dh, 0                    ; Cabeza 0
    mov dl, [boot_drive]         ; Unidad de arranque
    int 0x13
    jc .disk_error
    
    ; ¿Necesitamos más cargas?
    cmp cx, 127                  ; ¿Quedan más de 127 sectores?
    jbe .kernel_loaded           ; Si no, terminamos
    
    ; Para kernels grandes, seguir cargando en incrementos de 127
    sub cx, 127                  ; Restar los 127 ya cargados
    mov si, msg_dots             ; Para mostrar progreso
    
.load_loop:
    ; Actualizar posición de carga
    add bx, 0xFE00               ; 127*512 = 65024 (0xFE00) bytes
    jnc .no_segment_change       ; Si no hay carry, no cambiar segmento
    
    ; Incrementar segmento si el offset superó 0xFFFF
    mov ax, es
    add ax, 0x1000               ; 0x1000 * 16 = 64K
    mov es, ax
    xor bx, bx                   ; Reiniciar offset
    
.no_segment_change:
    ; Mostrar un punto para indicar progreso
    push cx
    mov ah, 0x0E
    mov al, '.'
    int 0x10
    pop cx
    
    ; Calcular cuántos sectores cargar ahora
    mov ah, 0x02                 ; Función de lectura
    mov al, 127                  ; Máximo 127 sectores
    cmp cx, 127                  ; ¿Quedan más de 127?
    jae .do_load                 ; Si sí, cargar 127
    mov al, cl                   ; Si no, cargar los restantes
    
.do_load:
    push cx                      ; Guardar contador restante
    add cl, 127                  ; Siguiente sector a leer
    adc ch, 0                    ; Manejar carry a CH (cilindro)
    and cl, 63                   ; Sector máximo es 63
    jnz .sector_ok
    inc cl                       ; Si llegó a 0, volver a 1
.sector_ok:
    int 0x13                     ; Leer desde disco
    jc .disk_error
    pop cx                       ; Restaurar contador
    
    ; Actualizar contador y comprobar si terminamos
    sub cx, 127
    ja .load_loop                ; Si quedan sectores, continuar
    
.kernel_loaded:
    ; --- Mostrar mensaje de kernel cargado ---
    mov si, msg_loaded
.print2:
    lodsb
    or al, al
    jz .jump_to_kernel
    mov ah, 0x0E
    int 0x10
    jmp .print2

.jump_to_kernel:
    ; Salto far a 0x0000:0x8000 (etiqueta start16 de kernel.asm)
    jmp 0x0000:0x8000

.disk_error:
    mov si, msg_disk_error
.print_err:
    lodsb
    or al, al
    jz .hang
    mov ah, 0x0E
    int 0x10
    jmp .print_err

.hang:
    cli
    hlt
    jmp .hang

; --- Mensajes ---
msg_loading       db "Bootloader: cargando kernel", 0
msg_dots          db ".", 0  
msg_loaded        db " Kernel cargado, saltando...", 0
msg_disk_error    db " Error leyendo disco.", 0

boot_drive        db 0             ; Unidad de arranque

; Relleno hasta 510 bytes y firma 0xAA55
times 510 - ($ - $$) db 0
dw 0xAA55