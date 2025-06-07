#ifndef KEYBOARD_H
#define KEYBOARD_H

#include <stdint.h>

#define KEYBOARD_DATA_PORT    0x60
#define KEYBOARD_STATUS_PORT  0x64

// Buffer de entrada
#define INPUT_BUFFER_SIZE 256

typedef struct {
    char buffer[INPUT_BUFFER_SIZE];
    int read_pos;
    int write_pos;
    int count;
} input_buffer_t;

// Funciones
void keyboard_init();
void keyboard_handler();
char keyboard_getchar();
int keyboard_gets(char* buffer, int max_len);

#endif