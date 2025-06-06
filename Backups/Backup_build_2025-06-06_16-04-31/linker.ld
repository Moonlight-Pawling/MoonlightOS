OUTPUT_FORMAT("elf64-x86-64")
ENTRY(start16)

SECTIONS
{
    /* Kernel starts at 0x8000 as expected by bootloader */
    . = 0x8000;
    
    /* Ensure .early16 section is first - this is critical! */
    .early16 : {
        *(.early16)
    }
    
    /* Then .pmode for 32-bit protected mode code */
    .pmode : {
        *(.pmode)
    }
    
    /* Then standard sections */
    .text : {
        *(.text)
    }
    
    .rodata : {
        *(.rodata)
    }
    
    .data : {
        *(.data)
    }
    
    .bss : {
        *(.bss)
        *(COMMON)
    }
}