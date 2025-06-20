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
    mov word [es:9*160], 0x0F49      ; 'I' - INICIO
    mov word [es:9*160+2], 0x0F4E
    mov word [es:9*160+4], 0x0F49
    mov word [es:9*160+6], 0x0F43
    mov word [es:9*160+8], 0x0F49
    mov word [es:9*160+10], 0x0F4F

    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Paso 1 completado - FILA 10
    mov ax, 0xB800
    mov es, ax
    mov word [es:10*160], 0x0A42      ; 'B' - BASICO
    mov word [es:10*160+2], 0x0A41
    mov word [es:10*160+4], 0x0A53
    mov word [es:10*160+6], 0x0A49
    mov word [es:10*160+8], 0x0A43
    mov word [es:10*160+10], 0x0A4F

    ; Habilitar A20 - FILA 11
    in al, 0x92
    or al, 2
    out 0x92, al

    mov word [es:11*160], 0x0A41      ; 'A' - A20 ON
    mov word [es:11*160+2], 0x0A32
    mov word [es:11*160+4], 0x0A30
    mov word [es:11*160+6], 0x0A4F
    mov word [es:11*160+8], 0x0A4E

    ; Añadir detección básica de memoria
    call detect_memory
    
    ; Cargar GDT protegida - FILA 12
    lgdt [gdt_descriptor]
    mov word [es:12*160], 0x0A47      ; 'G' - GDT OK
    mov word [es:12*160+2], 0x0A44
    mov word [es:12*160+4], 0x0A54
    mov word [es:12*160+6], 0x0A4F
    mov word [es:12*160+8], 0x0A4B

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
    mov dword [0xB8000 + 13*160], 0x0F500F52     ; 'PROT' - PROTEGIDO
    mov dword [0xB8000 + 13*160 + 4], 0x0F4F0F54
    mov dword [0xB8000 + 13*160 + 8], 0x0F450F47
    mov dword [0xB8000 + 13*160 + 12], 0x0F440F49
    mov dword [0xB8000 + 13*160 + 16], 0x0F200F4F

    ; Inicialización de segmentos - FILA 14
    mov eax, 0
    mov dword [0xB8000 + 14*160], 0x0F530F45     ; 'SEGM' - SEGMENTOS
    mov dword [0xB8000 + 14*160 + 4], 0x0F470F45
    mov dword [0xB8000 + 14*160 + 8], 0x0F450F4D
    mov dword [0xB8000 + 14*160 + 12], 0x0F540F4E
    mov dword [0xB8000 + 14*160 + 16], 0x0F530F4F

    ; Preparación para PAE - FILA 15
    mov eax, cr4
    mov dword [0xB8000 + 15*160], 0x0F500F41     ; 'PAE ' - PAE START
    mov dword [0xB8000 + 15*160 + 4], 0x0F200F45
    mov dword [0xB8000 + 15*160 + 8], 0x0F540F53
    mov dword [0xB8000 + 15*160 + 12], 0x0F520F41
    mov dword [0xB8000 + 15*160 + 16], 0x0F200F54

    ; Mostrar valor CR4 - FILA 16
    mov ebx, eax
    and ebx, 0x0F
    add ebx, 0x30
    mov dword [0xB8000 + 16*160], 0x0F520F43     ; 'CR4 ' - CR4 CONFIG
    mov dword [0xB8000 + 16*160 + 4], 0x0F200F34
    mov dword [0xB8000 + 16*160 + 8], 0x0F4F0F43
    mov dword [0xB8000 + 16*160 + 12], 0x0F460F4E
    mov dword [0xB8000 + 16*160 + 16], 0x0F470F49

    ; Activar PAE - FILA 17
    mov dword [0xB8000 + 17*160], 0x0F450F58     ; 'EXTE' - EXTENSIONES
    mov dword [0xB8000 + 17*160 + 4], 0x0F540F4E
    mov dword [0xB8000 + 17*160 + 8], 0x0F4E0F45
    mov dword [0xB8000 + 17*160 + 12], 0x0F490F53
    mov dword [0xB8000 + 17*160 + 16], 0x0F4E0F4F

    ; Habilitar bandera PAE en CR4 - FILA 18
    or eax, 1 << 5
    mov dword [0xB8000 + 18*160], 0x0F410F50     ; 'PAE ' - PAE ENABLE
    mov dword [0xB8000 + 18*160 + 4], 0x0F450F45
    mov dword [0xB8000 + 18*160 + 8], 0x0F4E0F45
    mov dword [0xB8000 + 18*160 + 12], 0x0F420F41
    mov dword [0xB8000 + 18*160 + 16], 0x0F450F4C

    ; PAE habilitada - FILA 19
    mov cr4, eax
    mov dword [0xB8000 + 19*160], 0x0F410F54     ; 'TABL' - TABLAS
    mov dword [0xB8000 + 19*160 + 4], 0x0F4C0F42
    mov dword [0xB8000 + 19*160 + 8], 0x0F530F41
    mov dword [0xB8000 + 19*160 + 12], 0x0F200F20
    mov dword [0xB8000 + 19*160 + 16], 0x0F4B0F4F

    ; Cargar estructura de paginación - FILA 20
    lea eax, [pml4]
    mov dword [0xB8000 + 20*160], 0x0F4D0F45     ; 'MEMO' - MEMORIA
    mov dword [0xB8000 + 20*160 + 4], 0x0F520F4F
    mov dword [0xB8000 + 20*160 + 8], 0x0F410F49
    mov dword [0xB8000 + 20*160 + 12], 0x0F200F20
    mov dword [0xB8000 + 20*160 + 16], 0x0F4B0F4F

    ; Mostrar dirección PML4 (último dígito hex) - FILA 21
    mov ebx, eax
    shr ebx, 12          ; Obtener los bits más significativos
    and ebx, 0x0F
    add ebx, 0x30
    cmp ebx, 0x39
    jle .ok
    add ebx, 7           ; Para A-F
.ok:
    mov dword [0xB8000 + 21*160], 0x0F500F4D     ; 'PML4' - PML4 READY
    mov dword [0xB8000 + 21*160 + 4], 0x0F340F4C
    mov dword [0xB8000 + 21*160 + 8], 0x0F520F20
    mov dword [0xB8000 + 21*160 + 12], 0x0F410F45
    mov dword [0xB8000 + 21*160 + 16], 0x0F590F44
    call delay_1s

    ; Cargar CR3 con dirección PML4 - FILA 22
    mov cr3, eax
    mov dword [0xB8000 + 22*160], 0x0F330F43     ; 'CR3 ' - CR3 LISTO
    mov dword [0xB8000 + 22*160 + 4], 0x0F200F52
    mov dword [0xB8000 + 22*160 + 8], 0x0F490F4C
    mov dword [0xB8000 + 22*160 + 12], 0x0F540F53
    mov dword [0xB8000 + 22*160 + 16], 0x0F200F4F
    call delay_1s

    ; Preparar registro MSR EFER - FILA 23
    mov ecx, 0xC0000080
    mov dword [0xB8000 + 23*160], 0x0F460F45     ; 'EFER' - EFER MSR
    mov dword [0xB8000 + 23*160 + 4], 0x0F520F45
    mov dword [0xB8000 + 23*160 + 8], 0x0F4D0F20
    mov dword [0xB8000 + 23*160 + 12], 0x0F520F53
    mov dword [0xB8000 + 23*160 + 16], 0x0F200F20
    call delay_1s

    ; Leer EFER - FILA 24
    rdmsr
    mov dword [0xB8000 + 24*160], 0x0F450F52     ; 'READ' - READ EFER
    mov dword [0xB8000 + 24*160 + 4], 0x0F440F41
    mov dword [0xB8000 + 24*160 + 8], 0x0F450F20
    mov dword [0xB8000 + 24*160 + 12], 0x0F450F46
    mov dword [0xB8000 + 24*160 + 16], 0x0F200F52
    call delay_1s

    ; === A PARTIR DE AQUÍ, COLUMNA 25 ===

    ; Activar LME en EFER - FILA 10, COLUMNA 25
    or eax, 1 << 8
    mov dword [0xB8000 + 10*160 + 50], 0x0F4C0F41    ; 'ACTIV' - ACTIVANDO LM
    mov dword [0xB8000 + 10*160 + 54], 0x0F540F43
    mov dword [0xB8000 + 10*160 + 58], 0x0F560F49
    mov dword [0xB8000 + 10*160 + 62], 0x0F4C0F20
    mov dword [0xB8000 + 10*160 + 66], 0x0F4D0F20
    call delay_1s

    ; Escribir EFER modificado - FILA 11, COLUMNA 25
    wrmsr
    mov dword [0xB8000 + 11*160 + 50], 0x0F4D0F58    ; 'X64 M' - X64 MODE ON
    mov dword [0xB8000 + 11*160 + 54], 0x0F440F36
    mov dword [0xB8000 + 11*160 + 58], 0x0F4F0F45
    mov dword [0xB8000 + 11*160 + 62], 0x0F450F44
    mov dword [0xB8000 + 11*160 + 66], 0x0F4E0F20
    call delay_1s

    ; Leer CR0 para paginación - FILA 12, COLUMNA 25
    mov eax, cr0
    mov dword [0xB8000 + 12*160 + 50], 0x0F500F43    ; 'CR0 P' - CR0 PAGINA
    mov dword [0xB8000 + 12*160 + 54], 0x0F300F52
    mov dword [0xB8000 + 12*160 + 58], 0x0F500F20
    mov dword [0xB8000 + 12*160 + 62], 0x0F470F41
    mov dword [0xB8000 + 12*160 + 66], 0x0F410F49
    call delay_1s

    ; Preparar paginación - FILA 13, COLUMNA 25
    or eax, 0x80000001
    mov dword [0xB8000 + 13*160 + 50], 0x0F560F56    ; 'VIRTU' - VIRTUAL MEM
    mov dword [0xB8000 + 13*160 + 54], 0x0F520F49
    mov dword [0xB8000 + 13*160 + 58], 0x0F550F54
    mov dword [0xB8000 + 13*160 + 62], 0x0F4C0F41
    mov dword [0xB8000 + 13*160 + 66], 0x0F4D0F20
    call delay_1s

    ; ¡MOMENTO CRÍTICO! Habilitar paginación - FILA 14, COLUMNA 25
    mov cr0, eax
    mov dword [0xB8000 + 14*160 + 50], 0x0F500F50    ; 'PAGIN' - PAGINACION
    mov dword [0xB8000 + 14*160 + 54], 0x0F470F41
    mov dword [0xB8000 + 14*160 + 58], 0x0F4E0F49
    mov dword [0xB8000 + 14*160 + 62], 0x0F430F41
    mov dword [0xB8000 + 14*160 + 66], 0x0F4F0F49
    call delay_1s

    ; Paginación exitosa - FILA 15, COLUMNA 25
    mov dword [0xB8000 + 15*160 + 50], 0x0F580F45    ; 'EXITO' - EXITOSO
    mov dword [0xB8000 + 15*160 + 54], 0x0F540F49
    mov dword [0xB8000 + 15*160 + 58], 0x0F200F4F
    mov dword [0xB8000 + 15*160 + 62], 0x0F4B0F4F
    mov dword [0xB8000 + 15*160 + 66], 0x0F210F21
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
    mov dword [0xB8000 + 16*160 + 50], 0x0F360F36    ; '64BIT' - 64 BITS OK
    mov dword [0xB8000 + 16*160 + 54], 0x0F420F34
    mov dword [0xB8000 + 16*160 + 58], 0x0F540F49
    mov dword [0xB8000 + 16*160 + 62], 0x0F4B0F53
    mov dword [0xB8000 + 16*160 + 66], 0x0F21
    call delay_1s

    ; Mensaje: "Saltando al kernel!" - FILA 17 (ajustado una fila más abajo)
    mov rsi, kernel_msg
    mov rdi, 0xB8000 + 17*160 + 50
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
    mov edi, 75000000
.loop:
    nop
    nop
    nop
    nop
    dec edi
    jnz .loop
    ret

section .bss
