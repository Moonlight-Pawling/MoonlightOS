OUTPUT_FORMAT("elf64-x86-64")
ENTRY(start16)

SECTIONS
{
    /* El kernel debe cargarse exactamente en la dirección física 0x8000 */
    . = 0x8000;
    
    /* Las secciones deben estar juntas sin alineamiento adicional */
    .early16 : {
        *(.early16)
    }
    
    .pmode : {
        *(.pmode)
    }
    
    .text : {
        *(.text)
        *(.data)
        *(.rodata)
        *(.bss)
    }
    
    /* Eliminar secciones innecesarias */
    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}