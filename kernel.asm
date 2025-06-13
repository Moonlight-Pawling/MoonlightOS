[BITS 16]
section .early16

; Exportar variables para que sean accesibles desde C
global total_mem_high
global total_mem_low

; Cabecera del kernel - permite carga dinámica
kernel_header:
    dw 64              ; Número de sectores que ocupa el kernel (ajustar durante la compilación)
    dw 0x1234          ; Firma mágica
    times 508 db 0     ; Padding para completar sector de 512 bytes

global start16
start16:
    ; Primero limpiar toda la pantalla para evitar artefactos de video
    mov ax, 0xB800
    mov es, ax
    xor di, di         ; Empezar desde el principio de la memoria de video
    mov ax, 0x0720     ; Espacio con atributo normal (fondo negro, texto gris)
    mov cx, 2000       ; 80x25 = 2000 caracteres en pantalla
    cld                ; Dirección de incremento
    rep stosw          ; Limpiar toda la pantalla
    
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
    mov byte [es:10*160], '1'        ; Fila 10, columna 0
    mov byte [es:10*160+1], 0x0A

    ; Habilitar A20 - FILA 11
    in al, 0x92
    or al, 2
    out 0x92, al

    mov byte [es:11*160], '2'        ; Fila 11, columna 0
    mov byte [es:11*160+1], 0x0A

    ; Detectar memoria disponible con int 0x15, eax=0xE820
    call detect_memory
    
    ; Cargar GDT protegida - FILA 12
    lgdt [gdt_descriptor]
    mov byte [es:12*160], '3'        ; Fila 12, columna 0
    mov byte [es:12*160+1], 0x0A

    ; Entrar a modo protegido
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_mode

; Rutina para detectar memoria disponible usando int 0x15, eax=0xE820
detect_memory:
    push es
    push di
    
    ; Configurar buffer en una ubicación segura
    mov ax, 0x0000
    mov es, ax
    mov di, 0x9000       ; Buffer temporal para E820
    
    xor ebx, ebx        ; ebx debe ser 0 para comenzar
    xor bp, bp          ; Contador de entradas
    mov edx, 0x534D4150 ; 'SMAP' en ASCII
    mov eax, 0xE820
    mov [es:di + 20], dword 1   ; Forzar ACPI 3.x entry
    mov ecx, 24         ; Tamaño del buffer
    int 0x15
    jc .error           ; Error si CF está activado
    
    mov edx, 0x534D4150 ; Algunas BIOSs pueden destruir edx
    cmp eax, edx
    jne .error          ; eax debe ser 'SMAP'
    
    test ebx, ebx       ; ebx = 0 significa lista de 1 entrada
    je .error
    jmp .start
    
.next_entry:
    mov eax, 0xE820
    mov [es:di + 20], dword 1
    mov ecx, 24
    int 0x15
    jc .done            ; CF = 1 significa final de lista
    mov edx, 0x534D4150 ; Restaurar edx
    
.start:
    jcxz .skip_entry    ; Si ecx=0, omitir entrada
    
    ; Procesar entrada: comprobar si es memoria utilizable (tipo=1)
    mov eax, [es:di + 16]   ; Tipo de entrada
    cmp eax, 1
    jne .skip_entry
    
    ; Es memoria utilizable, sumamos al total
    mov eax, [es:di + 8]    ; Tamaño (bits bajos)
    mov ebx, [es:di + 12]   ; Tamaño (bits altos)
    
    ; Acumular memoria total
    add [total_mem_low], eax
    adc [total_mem_high], ebx
    
    inc bp              ; Incrementar contador de entradas
    add di, 24          ; Siguiente entrada
    
.skip_entry:
    test ebx, ebx       ; Si ebx=0, fin de la lista
    jne .next_entry
    
.done:
    ; bp contiene el número de entradas
    mov [mem_entries], bp
    
    ; Si no se encontró memoria, usar valor predeterminado
    mov eax, [total_mem_low]
    or eax, [total_mem_high]
    jnz .memory_ok
    
    ; Valor predeterminado: 4GB
    mov dword [total_mem_low], 0x00000000
    mov dword [total_mem_high], 0x00000001 ; 4GB = 0x100000000
    
.memory_ok:
    pop di
    pop es
    ret
    
.error:
    ; En caso de error, usar un valor predeterminado para memoria
    mov dword [total_mem_high], 0
    mov dword [total_mem_low], 0x40000000  ; 1GB por defecto
    pop di
    pop es
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

    ; "34" - FILA 13
    mov dword [0xB8000 + 13*160], 0x0F340F33
    
    ; "BB" - FILA 14
    mov eax, 0
    mov dword [0xB8000 + 14*160], 0x0F420F42
    
    ; "CC" - FILA 15 - Leer CR4
    mov eax, cr4
    mov dword [0xB8000 + 15*160], 0x0F430F43
    
    ; Mostrar valor CR4 - FILA 16
    mov ebx, eax
    and ebx, 0x0F
    add ebx, 0x30
    mov [0xB8000 + 16*160], bl
    mov byte [0xB8000 + 16*160 + 1], 0x0F
    
    ; "DD" - FILA 17
    mov dword [0xB8000 + 17*160], 0x0F440F44
    
    ; "EE" - FILA 18 - Preparar PAE
    or eax, 1 << 5
    mov dword [0xB8000 + 18*160], 0x0F450F45
    
    ; "FF" - FILA 19 - Habilitar PAE
    mov cr4, eax
    mov dword [0xB8000 + 19*160], 0x0F460F46

    ; "GG" - FILA 20 - Cargar dirección PML4
    lea eax, [pml4]
    mov dword [0xB8000 + 20*160], 0x0F470F47
    
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

    ; "HH" - FILA 22 - Cargar CR3
    mov cr3, eax
    mov dword [0xB8000 + 22*160], 0x0F480F48
    call delay_1s

    ; "II" - FILA 23 - Preparar EFER
    mov ecx, 0xC0000080
    mov dword [0xB8000 + 23*160], 0x0F490F49
    call delay_1s

    ; "JJ" - FILA 24 - Leer EFER
    rdmsr
    mov dword [0xB8000 + 24*160], 0x0F4A0F4A
    call delay_1s

    ; === A PARTIR DE AQUÍ, COLUMNA 10 ===

    ; "KK" - FILA 9, COLUMNA 10 - Modificar EFER
    or eax, 1 << 8
    mov dword [0xB8000 + 9*160 + 20], 0x0F4B0F4B   ; +20 = columna 10
    call delay_1s

    ; "LL" - FILA 10, COLUMNA 10 - Escribir EFER
    wrmsr  
    mov dword [0xB8000 + 10*160 + 20], 0x0F4C0F4C  ; +20 = columna 10
    call delay_1s

    ; "MM" - FILA 11, COLUMNA 10 - Leer CR0
    mov eax, cr0
    mov dword [0xB8000 + 11*160 + 20], 0x0F4D0F4D  ; +20 = columna 10
    call delay_1s

    ; "NN" - FILA 12, COLUMNA 10 - Preparar paginación
    or eax, 0x80000001
    mov dword [0xB8000 + 12*160 + 20], 0x0F4E0F4E  ; +20 = columna 10
    call delay_1s

    ; "OO" - FILA 13, COLUMNA 10 - ¡MOMENTO CRÍTICO! Habilitar paginación
    mov cr0, eax
    mov dword [0xB8000 + 13*160 + 20], 0x0F4F0F4F  ; +20 = columna 10, Si ves esto, ¡paginación OK!
    call delay_1s

    ; "PP" - FILA 14, COLUMNA 10 - Paginación exitosa
    mov dword [0xB8000 + 14*160 + 20], 0x0F500F50  ; +20 = columna 10
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

    ; "QQ" - FILA 15, COLUMNA 10 - Long mode alcanzado
    mov dword [0xB8000 + 15*160 + 20], 0x0F510F51  ; +20 = columna 10

    ; Mensaje: "Saltando al kernel!" - FILA 16
    mov rsi, kernel_msg
    mov rdi, 0xB8000 + 16*160 + 20
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

kernel_msg db "Saltando al kernel!", 0

; Variables para almacenar información de memoria
mem_entries dw 0
total_mem_low dd 0           ; Variable exportada a C 
total_mem_high dd 0          ; Variable exportada a C

; --- Tablas de paginación con sección dedicada ---
; IMPORTANTE: Volver a la configuración simple que funcionaba originalmente
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
    ; Esta configuración mapea los primeros 2MB, que incluyen el búfer de video en 0xB8000
    dq 0x00000000 + 0x83        ; Present + Writable + Huge (2MB)
    
    ; Añadir más mapeos para tener acceso a más memoria (cada entrada = 2MB)
    ; Esto extenderá el mapeo hasta 1GB manteniendo la compatibilidad con el búfer de video
    %assign i 1
    %rep 511
        dq (i * 0x200000) + 0x83    ; Dirección base + flags
        %assign i i+1
    %endrep

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