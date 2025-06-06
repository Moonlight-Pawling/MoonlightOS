// Kernel en modo protegido (32 bits)
#include <stdint.h>

// Define un puntero a la memoria de video
volatile uint16_t* video = (volatile uint16_t*)0xB8000;

// Escribe un carácter en la memoria de video
void putchar(int x, int y, char c, uint8_t color) {
    const int index = y * 80 + x;
    video[index] = ((uint16_t)color << 8) | c;
}

// Escribe una cadena en pantalla
void print(int x, int y, const char* str, uint8_t color) {
    for (int i = 0; str[i]; i++) {
        putchar(x + i, y, str[i], color);
    }
}

// Punto de entrada del kernel
void kernel_main() {
    // Mensaje en la tercera línea
    print(0, 2, "Kernel C en 32-bits", 0x0A);
    
    // Mensaje en la cuarta línea
    print(0, 3, "Sistema estabilizado!", 0x0F);
}