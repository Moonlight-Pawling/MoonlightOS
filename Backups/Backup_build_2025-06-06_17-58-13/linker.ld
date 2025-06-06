OUTPUT_FORMAT("elf32-i386")
ENTRY(start16)

SECTIONS
{
    /* Cargar kernel en 0x8000 */
    . = 0x8000;
    
    /* Sección inicial 16 bits */
    .early16 : {
        *(.early16)
    }
    
    /* Incluir todas las secciones necesarias */
    .text : {
        *(.text)
    }
    
    .data : {
        *(.data)
    }
    
    .bss : {
        *(.bss)
    }
    
    .rodata : {
        *(.rodata)
    }
    
    /* Descartar el resto */
    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}