#include <stdint.h>

void kernel_main(void) {
    const char *msg = "Hola Mundo desde modo largo!\n";
    volatile uint16_t *vga = (volatile uint16_t*)0xB8000;
    for (int i = 0; msg[i]; i++) {
        vga[i] = (uint16_t)msg[i] | (0x0F << 8); // Letra blanca sobre fondo negro
    }
    while (1) {
        __asm__("hlt");
    }
}
