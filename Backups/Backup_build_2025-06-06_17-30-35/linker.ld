OUTPUT_FORMAT("elf64-x86-64")
ENTRY(start16)

SECTIONS
{
    /* Cargar kernel en 0x8000 */
    . = 0x8000;
    
    /* Colocar sección early16 al principio */
    .early16 : {
        *(.early16)
    }
    
    /* Descartar el resto por ahora */
    /DISCARD/ : {
        *(.text)
        *(.data)
        *(.rodata)
        *(.bss)
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}