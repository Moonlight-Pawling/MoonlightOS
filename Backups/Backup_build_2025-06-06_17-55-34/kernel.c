// Kernel en modo protegido (32 bits)
#include <stdint.h>

// Define un puntero a la memoria de video
volatile uint16_t* video = (volatile uint16_t*)0xB8000;

// Limpia la pantalla completa
void clear_screen(uint8_t color_attr) {
    // El atributo de color se coloca en los 8 bits altos
    // El caracter ' ' (espacio) es 0x20
    uint16_t blank = ((uint16_t)color_attr << 8) | 0x20;
    
    // Llenar toda la pantalla (80x25=2000 caracteres)
    for (int i = 0; i < 2000; i++) {
        video[i] = blank;
    }
}

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
    // Limpiar la pantalla (fondo negro, texto gris claro)
    clear_screen(0x07);
    
    // Mensaje en la primera línea
    print(0, 0, "Kernel C en 32 bits", 0x0A);
    
    // Mensaje en la segunda línea
    print(0, 1, "Sistema estabilizado!", 0x0F);
    while (1)
    {
    	
    }
}