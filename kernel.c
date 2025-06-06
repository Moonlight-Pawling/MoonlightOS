#include <stdint.h>

void kernel_main(void) {
    // Mensaje de éxito claro
    const char *msg = "*** KERNEL EN C EJECUTÁNDOSE EN MODO 64-BIT ***";
    volatile uint16_t *vga = (volatile uint16_t*)0xB8000;
    
    // Limpiar la pantalla primero
    for (int i = 0; i < 80*25; i++) {
        vga[i] = (uint16_t)' ' | (0x07 << 8); // Gris sobre negro
    }
    
    // Escribir mensaje centrado en la línea 10
    int offset = 10*80 + (80 - 43) / 2;
    for (int i = 0; msg[i]; i++) {
        vga[offset + i] = (uint16_t)msg[i] | (0x0F << 8); // Blanco brillante
    }
    
    // Bucle infinito
    while (1) {
        __asm__("hlt");
    }
}