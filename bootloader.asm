[BITS 16]
[ORG 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov [boot_drive], dl        ; Guardar unidad de arranque

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
    mov si, msg_dots             ; Preparar mensaje de puntos
    mov ax, 0                    ; Segmento ES = 0
    mov es, ax
    mov bx, 0x8000               ; Offset inicial
    mov ah, 0x02                 ; Función de lectura
    mov ch, 0                    ; Cilindro 0
    mov dh, 0                    ; Cabeza 0
    mov dl, [boot_drive]         ; Unidad de arranque
    
    ; Variables para el bucle de carga
    mov byte [sector_count], 0   ; Sectores cargados
    mov cx, KERNEL_SECTORS       ; Total sectores a cargar
    mov cl, 2                    ; Empezar en el sector 2

.load_loop:
    cmp cx, 0                    ; ¿Quedan sectores por cargar?
    jle .kernel_loaded           ; Si no, terminamos
    
    cmp cx, 127                  ; ¿Quedan más de 127 sectores?
    jle .last_chunk              ; Si no, último fragmento
    
    mov al, 127                  ; Cargar 127 sectores (máximo por operación)
    jmp .do_load
    
.last_chunk:
    mov al, cl                   ; Cargar los sectores restantes
    
.do_load:
    pusha                        ; Guardar registros
    int 0x13                     ; Llamar BIOS para leer disco
    jc .disk_error               ; Si CF=1, error
    popa                         ; Restaurar registros
    
    ; Mostrar un punto para indicar progreso
    push cx
    mov ah, 0x0E
    mov al, '.'
    int 0x10
    pop cx
    
    ; Actualizar posición y contador
    add bx, 127 * 512            ; Siguiente posición (127 sectores * 512 bytes)
    cmp bx, 0                    ; ¿Overflow del offset?
    jne .no_segment_adjust
    
    push ax
    mov ax, es
    add ax, 0x1000               ; Ajustar segmento (+64KB)
    mov es, ax
    pop ax
    
.no_segment_adjust:
    add byte [sector_count], 127 ; Actualizar sectores leídos
    add cl, 127                  ; Siguiente sector a leer
    sub cx, 127                  ; Restar sectores cargados
    jmp .load_loop               ; Repetir hasta cargar todo

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
    ; Salto far a 0x0000:0x8000
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

sector_count      db 0             ; Contador de sectores leídos
boot_drive        db 0             ; Unidad de arranque

; Relleno hasta 510 bytes y firma 0xAA55
times 510 - ($ - $$) db 0
dw 0xAA55