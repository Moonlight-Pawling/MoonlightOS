ENTRY(start16)

SECTIONS
{
    . = 0x8000;
    .early16 : { *(.early16) }
    .text : { *(.text) }
    .data : { *(.data) }
    .bss : { *(.bss) }
    .rodata : { *(.rodata) }
    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}