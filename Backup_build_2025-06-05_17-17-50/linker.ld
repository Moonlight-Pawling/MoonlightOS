ENTRY(start)

SECTIONS
{
    /* ------------------------------------------------
     * Trampolín 16 bits + GDT = sección .early16,
     * cargado por el bootloader en 0x8000.
     * ------------------------------------------------ */
    . = 0x8000;
    .early16 : {
        *(.early16)
    }

    /* ------------------------------------------------
     * Código x86_32 para protected mode: sección .pmode,
     * ubicado justo después a 0x9000 (dentro de <64 KiB).
     * ------------------------------------------------ */
    . = 0x9000;
    .pmode : {
        *(.pmode)
    }

    /* ------------------------------------------------
     * Kernel principal en modo largo (64 bits):
     * sección .text (y siguientes) ubicada en 1 MiB.
     * ------------------------------------------------ */
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
