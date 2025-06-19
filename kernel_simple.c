// Kernel simplificado en modo largo (64 bits) - MoonlightOS
#include <stdint.h>

// Define un puntero a la memoria de video
volatile uint16_t* video = (volatile uint16_t*)0xB8000;

// Variables externas desde kernel.asm
extern uint32_t total_mem_low;
extern uint32_t total_mem_high;
extern uint32_t mapped_memory_mb;

// Limpia la pantalla completa
void clear_screen(uint8_t color_attr) {
    uint16_t blank = ((uint16_t)color_attr << 8) | 0x20;
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

// Punto de entrada del kernel 64-bit
void kernel_main() {
    // Limpiar la pantalla
    clear_screen(0x07);

    // Header principal
    print(0, 0, "===============================================================================", 0x0F);
    print(0, 1, "            MoonlightOS - Modo Largo (64-bit) - VERSION SIMPLE", 0x0F);
    print(0, 2, "===============================================================================", 0x0F);

    // Información del sistema
    print(0, 4, "Sistema inicializado correctamente", 0x0A);
    print(0, 5, "Version TEST para diagnosticar problemas de carga", 0x0C);

    print(0, 10, "Si puedes ver este mensaje, el bootloader cargo el kernel correctamente", 0x0A);

    // Bucle infinito
    while(1) {
        // Animar un caracter para mostrar que el sistema está vivo
        for (int i = 0; i < 4; i++) {
            char symbol;
            switch (i % 4) {
                case 0: symbol = '|'; break;
                case 1: symbol = '/'; break;
                case 2: symbol = '-'; break;
                case 3: symbol = '\\'; break;
            }
            putchar(79, 24, symbol, 0x0E);

            // Retardo
            for (volatile uint64_t j = 0; j < 50000000; j++) {}
        }
    }
}
