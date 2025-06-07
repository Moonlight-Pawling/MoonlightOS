#ifndef CONSOLE_H
#define CONSOLE_H

#include <stdint.h>

#define CONSOLE_WIDTH  80
#define CONSOLE_HEIGHT 25
#define MAX_COMMAND_LEN 256

// Estructura del shell
typedef struct {
    char command_buffer[MAX_COMMAND_LEN];
    int cursor_pos;
    int current_line;
    char* current_user;
    int is_admin;
} shell_state_t;

// Funciones básicas
void console_init();
void console_print_prompt();
void console_execute_command(const char* command);
void console_main_loop();

// Comandos básicos
void cmd_help();
void cmd_clear();
void cmd_whoami();
void cmd_login();
void cmd_logout();

#endif