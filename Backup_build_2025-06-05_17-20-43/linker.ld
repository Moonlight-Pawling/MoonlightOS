ENTRY(start)

SECTIONS
{
    /* -------------------------------
     * Sección .early16 (16 bits + GDT),
     * cargada por el bootloader en 0x8000.
     * ------------------------------- */
    . = 0x8000;
    .early16 : {
        *(.early16)
    }

    /* ------------------------------------
     * Sección .pmode (32 bits, protected),
     * ubicada en 0x9000 (<64 KiB).
     * ------------------------------------ */
    . = 0x9000;
    .pmode : {
        *(.pmode)
    }

    /* ------------------------------------
     * Sección .text y siguientes (64 bits),
     * ubicada en 0x100000 (1 MiB).
     * ------------------------------------ */
    . = 0x100000;
    .text : {
        *(.text)
    }
    .rodata : {
        *(.rodata*)
    }
    .data : {
        *(.data*)
    }
    .bss : {
        *(.bss)
        *(COMMON)
    }
}
