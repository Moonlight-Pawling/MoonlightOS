OUTPUT_FORMAT("elf64-x86-64")
ENTRY(start16)

SECTIONS
{
    /* El kernel se cargará en la dirección física 0x8000 */
    . = 0x8000;
    
    /* Asegurarse de que .early16 es exactamente la primera sección */
    .early16 : ALIGN(1) {
        *(.early16)
    }
    
    /* Asegurarse de que .pmode comienza inmediatamente después de .early16 */
    .pmode : ALIGN(1) {
        *(.pmode)
    }
    
    /* Todas las demás secciones */
    .text : ALIGN(1) {
        *(.text)
    }
    
    .rodata : ALIGN(1) {
        *(.rodata)
    }
    
    .data : ALIGN(1) {
        *(.data)
    }
    
    .bss : ALIGN(1) {
        *(.bss)
        *(COMMON)
    }
    
    /* Eliminar secciones innecesarias para reducir el tamaño del binario */
    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}