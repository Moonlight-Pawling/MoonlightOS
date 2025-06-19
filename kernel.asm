[BITS 16]
section .early16

; Exportar variables para que sean accesibles desde C
global total_mem_high
global total_mem_low
global mapped_memory_mb  ; Nueva variable para memoria mapeada

; Cabecera del kernel - permite carga dinámica (solo añadir esto al principio)
kernel_header:
    dd 64              ; Número de sectores (ahora 4 bytes, no 2)
    dw 0x1234          ; Firma mágica (offset +4)
    dd 0x00000000      ; Reservado
    dq 0x0000000000000000

global start16
start16:
    ; Diagnóstico visual inicial - FILA 9
    mov ax, 0xB800
    mov es, ax
    mov byte [es:9*160], '*'        ; Fila 9, columna 0
    mov byte [es:9*160+1], 0x0F

    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Paso 1 completado - FILA 10
    mov ax, 0xB800
    mov es, ax
    mov byte [es:10*160], 'I'        ; Fila 10, columna 0 - Inicio
    mov byte [es:10*160+1], 0x0A

    ; Habilitar A20 - FILA 11
    in al, 0x92
    or al, 2
    out 0x92, al

    mov byte [es:11*160], 'A'        ; Fila 11, columna 0 - A20 activada
    mov byte [es:11*160+1], 0x0A

    ; Añadir detección básica de memoria
    call detect_memory
    
    ; Cargar GDT protegida - FILA 12
    lgdt [gdt_descriptor]
    mov byte [es:12*160], 'G'        ; Fila 12, columna 0 - GDT cargada
    mov byte [es:12*160+1], 0x0A

    ; Entrar a modo protegido
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_mode

; Rutina mínima para detectar memoria
detect_memory:
    ; Configurar 1GB por defecto (valor seguro)
    mov dword [total_mem_high], 0
    mov dword [total_mem_low], 0x40000000  ; 1GB
    ret

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

    ; Indicador de modo protegido - FILA 13
    mov dword [0xB8000 + 13*160], 0x0F500F33  ; "P3" - Modo Protegido 32-bits

    ; Inicialización de segmentos - FILA 14
    mov eax, 0
    mov dword [0xB8000 + 14*160], 0x0F530F49  ; "IS" - Inicialización de Segmentos

    ; Preparación para PAE - FILA 15
    mov eax, cr4
    mov dword [0xB8000 + 15*160], 0x0F450F50  ; "PE" - Preparando PAE Extension

    ; Mostrar valor CR4 - FILA 16
    mov ebx, eax
    and ebx, 0x0F
    add ebx, 0x30
    mov [0xB8000 + 16*160], bl
    mov byte [0xB8000 + 16*160 + 1], 0x0F
    
    ; "DD" - FILA 17
    mov dword [0xB8000 + 17*160], 0x0F440F44
    
    ; Activar PAE - FILA 17
    mov dword [0xB8000 + 17*160], 0x0F410F50  ; "PA" - PAE Activación

    ; Habilitar bandera PAE en CR4 - FILA 18
    or eax, 1 << 5
    mov dword [0xB8000 + 18*160], 0x0F430F50  ; "PC" - PAE en CR4

    ; PAE habilitada - FILA 19
    mov cr4, eax
    mov dword [0xB8000 + 19*160], 0x0F480F50  ; "PH" - PAE Habilitada

    ; Cargar estructura de paginación - FILA 20
    lea eax, [pml4]
    mov dword [0xB8000 + 20*160], 0x0F430F54  ; "TC" - Tablas Cargadas

    ; Mostrar dirección PML4 (último dígito hex) - FILA 21
    mov ebx, eax
    shr ebx, 12          ; Obtener los bits más significativos
    and ebx, 0x0F
    add ebx, 0x30
    cmp ebx, 0x39
    jle .ok
    add ebx, 7           ; Para A-F
.ok:
    mov [0xB8000 + 21*160], bl
    mov byte [0xB8000 + 21*160 + 1], 0x0F
    call delay_1s

    ; Cargar CR3 con dirección PML4 - FILA 22
    mov cr3, eax
    mov dword [0xB8000 + 22*160], 0x0F330F43  ; "C3" - CR3 cargado con PML4
    call delay_1s

    ; Preparar registro MSR EFER - FILA 23
    mov ecx, 0xC0000080
    mov dword [0xB8000 + 23*160], 0x0F450F45  ; "EE" - EFER (MSR) preparado
    call delay_1s

    ; Leer EFER - FILA 24
    rdmsr
    mov dword [0xB8000 + 24*160], 0x0F4C0F45  ; "EL" - EFER Leído
    call delay_1s

    ; === A PARTIR DE AQUÍ, COLUMNA 25 ===

    ; Activar LME en EFER - FILA 10, COLUMNA 25
    or eax, 1 << 8
    mov dword [0xB8000 + 10*160 + 50], 0x0F200F4C  ; "L " - Activando Long Mode
    call delay_1s

    ; Escribir EFER modificado - FILA 11, COLUMNA 25
    wrmsr
    mov dword [0xB8000 + 11*160 + 50], 0x0F200F4D  ; "M " - Modo Largo habilitado
    call delay_1s

    ; Leer CR0 para paginación - FILA 12, COLUMNA 25
    mov eax, cr0
    mov dword [0xB8000 + 12*160 + 50], 0x0F310F50  ; "P1" - Preparando CR0
    call delay_1s

    ; Preparar paginación - FILA 13, COLUMNA 25
    or eax, 0x80000001
    mov dword [0xB8000 + 13*160 + 50], 0x0F320F50  ; "P2" - Preparando Paginación
    call delay_1s

    ; ¡MOMENTO CRÍTICO! Habilitar paginación - FILA 14, COLUMNA 25
    mov cr0, eax
    mov dword [0xB8000 + 14*160 + 50], 0x0F330F50  ; "P3" - Paginación Activada!
    call delay_1s

    ; Paginación exitosa - FILA 15, COLUMNA 25
    mov dword [0xB8000 + 15*160 + 50], 0x0F4B0F4F  ; "OK" - Paginación Correcta
    call delay_1s

    ; Saltar a long mode
    jmp 0x18:long_mode_start

; --- LONG MODE (64 bits) ---
[BITS 64]
long_mode_start:
    mov ax, 0x10        ; Usar selector de datos de 32-bit para compatibilidad
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov rsp, 0x90000

    ; Modo Largo alcanzado - FILA 16, COLUMNA 10 (desplazado una fila más abajo)
    mov dword [0xB8000 + 16*160 + 20], 0x0F340F36  ; "64" - Modo 64-bits
    call delay_1s

    ; Mensaje: "Saltando al kernel!" - FILA 17 (ajustado una fila más abajo)
    mov rsi, kernel_msg
    mov rdi, 0xB8000 + 17*160 + 20
    call print_string_64
    call delay_1s
    call delay_1s

    extern kernel_main
    call kernel_main

.hang:
    hlt
    jmp .hang

; === FUNCIÓN PARA IMPRIMIR STRING EN 64-BIT ===
print_string_64:
    push rax
    push rcx
    
.loop:
    lodsb                   ; Cargar byte de [rsi] a al, incrementar rsi
    test al, al             ; ¿Es null terminator?
    jz .done
    
    mov [rdi], al           ; Escribir carácter
    mov byte [rdi + 1], 0x0A ; Color verde brillante
    add rdi, 2              ; Siguiente posición en pantalla
    jmp .loop
    
.done:
    pop rcx
    pop rax
    ret

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

kernel_msg db "Modo Largo 64-bit activo! Saltando al kernel C...", 0

; Variables para almacenar información de memoria (consolidadas aquí)
total_mem_low dd 0           ; Variable exportada a C
total_mem_high dd 0          ; Variable exportada a C
mapped_memory_mb dd 128      ; Nueva variable: memoria mapeada en MB (62 páginas * 2MB)

; --- Tablas de paginación con sección dedicada ---
section .paging
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
    ; Mapear 128 MB (62 entradas de 2 MB cada una)
    %assign i 0
    %rep 64
        dq (i * 0x200000) + 0x83    ; Cada entrada mapea 2MB, con flags 0x83 (presente, escritura, tamaño grande)
        %assign i i+1
    %endrep
    times (512-64) dq 0             ; Rellenar el resto de la tabla

section .text
; ===== FUNCIÓN DE DELAY =====
delay_1s:
    mov edi, 100000000
.loop:
    nop
    nop
    nop
    nop
    dec edi
    jnz .loop
    ret

section .bss
