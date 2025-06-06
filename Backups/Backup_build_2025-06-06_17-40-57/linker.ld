OUTPUT_FORMAT("elf64-x86-64")
ENTRY(start16)

SECTIONS
{
    /* Cargar kernel en 0x8000 */
    . = 0x8000;
    
    /* Sección inicial 16 bits */
    .early16 : {
        *(.early16)
    }
    
    /* Incluir todas las secciones importantes */
    .data : {
        *(.data)
    }
    
    .bss : {
        *(.bss)
    }
    
    /* Descartar el resto por ahora */
    /DISCARD/ : {
        *(.text)
        *(.rodata)
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}