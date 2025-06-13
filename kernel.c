// Kernel en modo largo (64 bits) - MoonlightOS
#include <stdint.h>

// Definir un puntero a la memoria de video con mapeo adecuado para 64 bits
volatile uint16_t* const video = (volatile uint16_t*)0xB8000;

// Variables externas desde kernel.asm para información de memoria
extern uint32_t total_mem_low;
extern uint32_t total_mem_high;

// Limpia la pantalla completa de forma segura
void clear_screen(uint8_t color_attr) {
    uint16_t blank = ((uint16_t)color_attr << 8) | 0x20; // Espacio con color
    
    // Usar el enfoque original que sabemos que funciona
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

// Función para convertir número a string hexadecimal
void uint64_to_hex(uint64_t value, char* buffer) {
    const char hex_chars[] = "0123456789ABCDEF";
    buffer[0] = '0';
    buffer[1] = 'x';
    
    for (int i = 15; i >= 0; i--) {
        buffer[2 + (15-i)] = hex_chars[(value >> (i * 4)) & 0xF];
    }
    buffer[18] = '\0';
}

// Función para convertir número a string decimal
void uint64_to_dec(uint64_t value, char* buffer) {
    if (value == 0) {
        buffer[0] = '0';
        buffer[1] = '\0';
        return;
    }
    
    char temp[32];
    int i = 0;
    
    while (value > 0) {
        temp[i++] = '0' + (value % 10);
        value /= 10;
    }
    
    for (int j = 0; j < i; j++) {
        buffer[j] = temp[i - 1 - j];
    }
    buffer[i] = '\0';
}

// Detectar cantidad de RAM desde variables externas
uint64_t detect_memory() {
    // Combinar total_mem_high y total_mem_low en un valor de 64 bits
    uint64_t memory_size = ((uint64_t)total_mem_high << 32) | (uint64_t)total_mem_low;
    
    // Si no se detectó, usar al menos 1GB
    if (memory_size == 0) {
        memory_size = 0x40000000ULL; // 1GB por defecto
    }
    
    return memory_size;
}

// Punto de entrada del kernel 64-bit
void kernel_main() {
    // Limpiar la pantalla
    clear_screen(0x07);
    
    // Header principal
    print(0, 0, "===============================================================================", 0x0F);
    print(0, 1, "                        MoonlightOS - Modo Largo (64-bit)", 0x0F);
    print(0, 2, "===============================================================================", 0x0F);
    
    // Información del sistema
    print(0, 4, "Sistema inicializado correctamente", 0x0A);
    print(0, 5, "Desarrollado por Moonlight-Pawling", 0x0C);
    
    // Mostrar información técnica
    char mem_str[32];
    uint64_t memory = detect_memory();
    uint64_to_hex(memory, mem_str);
    
    // Mostrar tamaño en GB
    char mem_gb_str[32];
    uint64_t memory_gb = memory / (1024*1024*1024);
    uint64_to_dec(memory_gb, mem_gb_str);
    
    print(0, 7, "Informacion del Sistema:", 0x0B);
    print(2, 8, "- Arquitectura: x86_64", 0x07);
    print(2, 9, "- Memoria detectada: ", 0x07);
    print(22, 9, mem_str, 0x0E);
    print(41, 9, "(", 0x07);
    print(42, 9, mem_gb_str, 0x0E);
    print(42 + 5, 9, " GB)", 0x07);
    print(2, 10, "- Paginacion: Activada (Acceso completo a RAM)", 0x07);
    print(2, 11, "- Modo: Long Mode 64-bit", 0x07);
    print(2, 12, "- GDT: Configurada", 0x07);
    print(2, 13, "- Carga de kernel: Dinamica", 0x0A);
    
    // Preparación para sistema de login
    print(0, 15, "Preparando sistema de usuarios...", 0x0D);
    print(0, 16, "* IDT: Pendiente", 0x08);
    print(0, 17, "* Teclado: Pendiente", 0x08);
    print(0, 18, "* Sistema de Login: Pendiente", 0x08);
    print(0, 19, "* Shell: Pendiente", 0x08);
    
    // Status bar
    print(0, 21, "Estado: Sistema base funcionando - Listo para expansiones", 0x0A);
    
    // Footer con timestamp y heartbeat
    print(0, 23, "Tiempo de funcionamiento: ", 0x07);
    
    // Heartbeat animado con contador
    uint64_t counter = 0;
    char heartbeat[] = {'|', '/', '-', '\\'};
    char counter_str[32];
    
    while(1) {
        // Mostrar heartbeat
        putchar(79, 24, heartbeat[counter % 4], 0x0E);
        
        // Mostrar contador de segundos
        uint64_to_dec(counter / 10, counter_str);
        print(26, 23, counter_str, 0x0E);
        print(26 + 10, 23, "s   ", 0x07); // Limpiar espacios extra
        
        // Retardo usando contador de 64 bits
        for (volatile uint64_t i = 0; i < 50000000ULL; i++) { }
        
        counter++;
        
        // Cada 50 ciclos, mostrar mensaje de sistema activo
        if (counter % 50 == 0) {
            print(0, 22, "Sistema activo y estable", 0x0A);
        }
    }
}