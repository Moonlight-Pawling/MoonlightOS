typedef unsigned char uint8_t;
typedef unsigned short uint16_t;

volatile uint16_t* VGA_MEMORY = (uint16_t*)0xB8000;
const int VGA_WIDTH = 80;

void kernel_main() {
    const char *message = "Hola Mundo desde kernel en C!";

    // Escribir mensaje en VGA
    for (int i = 0; message[i] != '\0'; i++) {
        VGA_MEMORY[i] = (uint16_t)message[i] | (0x0F << 8);  // letra blanca sobre negro
    }

    // Bucle infinito
    while (1) {}
}
