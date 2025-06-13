ENTRY(start16)

SECTIONS
{
    . = 0x8000;
    
    /* La cabecera del kernel debe ser lo primero */
    .header : {
        *(.early16)
    }
    
    /* Resto del kernel */
    .text : {
        *(.text)
    }
    
    .data : {
        *(.data)
    }
    
    .paging : {
        *(.paging)
    }
    
    .bss : {
        *(.bss)
    }
    
    .rodata : {
        *(.rodata)
    }
    
    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}