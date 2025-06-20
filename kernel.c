// Kernel en modo largo (64 bits) - MoonlightOS
#include <stdint.h>
#include <stddef.h> // Para NULL

// Define un puntero a la memoria de video
volatile uint16_t* video = (volatile uint16_t*)0xB8000;

// Constantes para la consola
#define CONSOLE_WIDTH 80
#define CONSOLE_HEIGHT 25
#define CONSOLE_INFO_AREA_HEIGHT 10     // Área para información del sistema (parte superior)
#define CONSOLE_STATUS_LINE 23          // Línea de estado (movida una línea más abajo)
#define CONSOLE_FOOTER_LINE 24          // Línea de pie de página con heartbeat
#define CONSOLE_START_X 0
#define CONSOLE_START_Y 12              // Iniciamos la consola más arriba para evitar solapamiento
#define CONSOLE_END_Y 23                // Extendemos el área de consola para mostrar más contenido
#define CONSOLE_PROMPT_COLOR 0x0B
#define CONSOLE_TEXT_COLOR 0x07
#define MAX_COMMAND_LENGTH 78           // Dejamos espacio para el prompt "> "
#define BACKSPACE 0x0E
#define ENTER 0x1C

// Constantes para Portal Shell
#define PORTAL_VERSION "1.0"
#define PORTAL_PROMPT "> "
#define MAX_ARGS 8      // Máximo número de argumentos para comandos
#define PORTAL_MAX_ARGS MAX_ARGS  // Alias para consistencia

// Constantes para los comandos
#define CMD_UNKNOWN 0
#define CMD_PROCESS 1
#define CMD_HELP 2
#define CMD_CLEAR 3
#define CMD_EXIT 4

// Estructura para comandos de Portal
typedef struct {
    char command[MAX_COMMAND_LENGTH + 1];
    char args[MAX_ARGS][MAX_COMMAND_LENGTH + 1];
    int argc;
} PortalCommand;

// Variables globales para Portal
volatile int portal_command_ready = 0;
char portal_command_buffer[MAX_COMMAND_LENGTH + 1];
char command_buffer[MAX_COMMAND_LENGTH + 1];

// Declaraciones anticipadas de las funciones del Portal Shell
void portal_init(void);
void portal_display_welcome(void);
void portal_print_prompt(void);
void portal_parse_command(char* input, PortalCommand* cmd);
int portal_execute_command(PortalCommand* cmd);
void send_to_portal(char* command);

// Constantes para el PIT (Programmable Interval Timer)
#define PIT_FREQUENCY 1193182        // Frecuencia base del PIT en Hz
#define PIT_CHANNEL0_DATA 0x40       // Puerto de datos del canal 0
#define PIT_COMMAND 0x43             // Puerto de comandos
#define PIT_TICKS_PER_SECOND 50      // Cambiado a 50 ticks por segundo (20ms por tick)

// Scancodes comunes del teclado (conjunto 1)
#define SCANCODE_A 0x1E
#define SCANCODE_Z 0x2C
#define SCANCODE_SPACE 0x39

// Definición para el sistema de procesos
#define MAX_PROCESSES 16
#define PROCESS_RUNNING 1
#define PROCESS_STOPPED 0

// Posiciones fijas para indicadores en línea de footer
#define FOOTER_RAMUSE_POS 2          // Posición para indicador de RAM
#define FOOTER_PROCS_POS 20          // Posición para contador de procesos
#define FOOTER_HEARTBEAT2_POS 40     // Posición para segundo heartbeat

// Estructura de proceso
typedef struct {
    uint8_t id;                    // ID del proceso
    uint8_t status;                // Estado (corriendo o detenido)
    char name[16];                 // Nombre del proceso
    uint64_t ticks;                // Contador de ticks del proceso
    void (*function)(uint64_t);    // Función que ejecuta el proceso
} Process;

// Variables globales para la consola
char input_buffer[MAX_COMMAND_LENGTH + 1];
int buffer_position = 0;
int cursor_x = 0;
int cursor_y = 0;

// Variables para el sistema de procesos
Process processes[MAX_PROCESSES];
uint8_t process_count = 0;
uint8_t active_processes = 0;

// Variables para el temporizador
volatile uint64_t pit_ticks = 0;     // Contador de ticks del PIT
volatile uint8_t seconds = 0;        // Contador de segundos
volatile uint8_t minutes = 0;        // Contador de minutos
volatile uint8_t hours = 0;          // Contador de horas

// Variables externas desde kernel.asm
extern uint32_t total_mem_low;
extern uint32_t total_mem_high;
extern uint32_t mapped_memory_mb;  // Nueva variable importada de kernel.asm

// Declaraciones anticipadas de funciones
void update_timestamp(void);
void process_key(uint8_t scancode);
uint8_t create_process(char* name, void (*function)(uint64_t));
void kill_process(uint8_t pid);
void run_processes(void);
int strcmp(const char* s1, const char* s2);

// Puerto de entrada/salida
void outb(uint16_t port, uint8_t value) {
    asm volatile("outb %0, %1" : : "a"(value), "Nd"(port));
}

// Función para leer un byte desde un puerto
uint8_t inb(uint16_t port) {
    uint8_t result;
    asm volatile("inb %1, %0" : "=a" (result) : "Nd" (port));
    return result;
}

// Inicializar el PIT para interrumpir a una frecuencia específica
void init_pit(uint32_t frequency) {
    uint32_t divisor = PIT_FREQUENCY / frequency;

    // Enviar comando al PIT: Canal 0, modo 3 (square wave), binario
    outb(PIT_COMMAND, 0x36);

    // Enviar divisor (primero byte bajo, luego byte alto)
    outb(PIT_CHANNEL0_DATA, divisor & 0xFF);           // LSB
    outb(PIT_CHANNEL0_DATA, (divisor >> 8) & 0xFF);    // MSB
}

// Limpia una región específica de la pantalla
void clear_region(int start_y, int end_y, uint8_t color_attr) {
    uint16_t blank = ((uint16_t)color_attr << 8) | 0x20;
    for (int y = start_y; y <= end_y; y++) {
        for (int x = 0; x < CONSOLE_WIDTH; x++) {
            video[y * CONSOLE_WIDTH + x] = blank;
        }
    }
}

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

// Convertir un valor a una cadena con ceros a la izquierda
void uint8_to_dec_padded(uint8_t value, char* buffer) {
    buffer[0] = '0' + (value / 10);
    buffer[1] = '0' + (value % 10);
    buffer[2] = '\0';
}

// Detectar cantidad de RAM
uint64_t detect_memory() {
    // Combinar las variables externas
    uint64_t memory_size = ((uint64_t)total_mem_high << 32) | total_mem_low;
    return memory_size;
}

// Función para esperar una tecla y obtener su scancode
uint8_t wait_for_key() {
    // Polling del puerto 0x64 (estado del teclado)
    while (!(inb(0x64) & 1));

    // Leer el scancode desde el puerto 0x60
    return inb(0x60);
}

// Establecer la posición del cursor
void set_cursor(int x, int y) {
    cursor_x = x;
    cursor_y = y;

    // Actualizar cursor en pantalla
    putchar(x, y, '_', CONSOLE_TEXT_COLOR);
}

// Actualizar posición del cursor y mostrar todo el contenido del buffer
void update_console_line() {
    // Limpiar la línea completa primero
    for (int i = 0; i < CONSOLE_WIDTH - 2; i++) {
        putchar(CONSOLE_START_X + 2 + i, cursor_y, ' ', CONSOLE_TEXT_COLOR);
    }

    // Mostrar el prompt en la posición correcta
    putchar(CONSOLE_START_X, cursor_y, '>', CONSOLE_PROMPT_COLOR);
    putchar(CONSOLE_START_X + 1, cursor_y, ' ', CONSOLE_PROMPT_COLOR);

    // Mostrar el buffer completo
    for (int i = 0; i < buffer_position; i++) {
        putchar(CONSOLE_START_X + 2 + i, cursor_y, input_buffer[i], CONSOLE_TEXT_COLOR);
    }

    // Actualizar cursor
    set_cursor(CONSOLE_START_X + 2 + buffer_position, cursor_y);
}

// Actualizar posición del cursor
void update_cursor() {
    // Borrar cursor anterior
    if (cursor_x > 0) {
        putchar(cursor_x, cursor_y, ' ', CONSOLE_TEXT_COLOR);
    }

    // Mover cursor a la nueva posición
    set_cursor(CONSOLE_START_X + buffer_position + 2, cursor_y); // +2 por el "> "
}

// Inicializar consola
void init_console() {
    // Limpiamos el área de consola primero
    clear_region(CONSOLE_START_Y, CONSOLE_END_Y, CONSOLE_TEXT_COLOR);

    // Título fijo de la consola (ahora indica disponibilidad de Portal)
    print(CONSOLE_START_X, CONSOLE_START_Y, "Shell Portal disponible, escriba 'portal' para ingresar a la shell", CONSOLE_PROMPT_COLOR);

    // Inicializamos el cursor debajo del título
    cursor_y = CONSOLE_START_Y + 1;
    print(CONSOLE_START_X, cursor_y, "> ", CONSOLE_PROMPT_COLOR);
    buffer_position = 0;
    input_buffer[0] = '\0';
    set_cursor(CONSOLE_START_X + 2, cursor_y);
}

// Convertir scancode a ASCII considerando el teclado en español/latino
char scancode_to_ascii(uint8_t scancode) {
    // Esquema de diagnóstico - mostrar el scancode recibido
    char debug_buffer[8];
    uint8_t safe_scancode = scancode & 0x7F; // Quitar el bit de liberación para el diagnóstico

    // Imprimir el código de escaneo en la esquina superior derecha (diagnóstico)
    debug_buffer[0] = 'S';
    debug_buffer[1] = 'C';
    debug_buffer[2] = ':';
    debug_buffer[3] = ' ';
    debug_buffer[4] = "0123456789ABCDEF"[(safe_scancode >> 4) & 0xF];
    debug_buffer[5] = "0123456789ABCDEF"[safe_scancode & 0xF];
    debug_buffer[6] = ' ';
    debug_buffer[7] = '\0';

    // Mostrar en pantalla en la esquina superior derecha para diagnóstico
    // Esta información puede ser valiosa para depurar problemas
    print(70, 0, debug_buffer, 0x0F);

    // Ignorar release codes (bit 7 activado)
    if (scancode & 0x80) {
        return 0;
    }

    // Mapeo seguro que verifica un rango válido de scancodes
    // Solo procesamos códigos entre 0x01 y 0x58 (códigos estándar del teclado PC)
    if (scancode < 0x01 || scancode > 0x58) {
        return 0; // Fuera de rango - ignorar
    }

    // Mapeo correcto para teclas principales
    if (scancode == 0x02) return '1';
    if (scancode == 0x03) return '2';
    if (scancode == 0x04) return '3';
    if (scancode == 0x05) return '4';
    if (scancode == 0x06) return '5';
    if (scancode == 0x07) return '6';
    if (scancode == 0x08) return '7';
    if (scancode == 0x09) return '8';
    if (scancode == 0x0A) return '9';
    if (scancode == 0x0B) return '0';

    // Símbolos especiales para teclado latinoamericano
    if (scancode == 0x0C) return '-';  // Tecla de guion/menos
    if (scancode == 0x0D) return '=';  // Tecla de igual
    if (scancode == 0x1A) return '\''; // Apóstrofe en vez de acento agudo (tilde muerta)
    if (scancode == 0x1B) return '+';  // Tecla de más
    if (scancode == 0x2B) return '}';  // Corchete/llave derecho
    if (scancode == 0x27) return 'n';  // 'n' normal en vez de 'ñ'
    if (scancode == 0x28) return '{';  // Corchete/llave izquierdo
    if (scancode == 0x33) return ',';  // Coma
    if (scancode == 0x34) return '.';  // Punto
    if (scancode == 0x35) return '-';  // Guion/menos (segunda ocurrencia en algunos teclados)

    // Primera fila de letras (QWERTY)
    if (scancode == 0x10) return 'q';
    if (scancode == 0x11) return 'w';
    if (scancode == 0x12) return 'e';
    if (scancode == 0x13) return 'r';
    if (scancode == 0x14) return 't';
    if (scancode == 0x15) return 'y';
    if (scancode == 0x16) return 'u';
    if (scancode == 0x17) return 'i';
    if (scancode == 0x18) return 'o';
    if (scancode == 0x19) return 'p';

    // Segunda fila de letras (ASDFG)
    if (scancode == 0x1E) return 'a';
    if (scancode == 0x1F) return 's';
    if (scancode == 0x20) return 'd';
    if (scancode == 0x21) return 'f';
    if (scancode == 0x22) return 'g';
    if (scancode == 0x23) return 'h';
    if (scancode == 0x24) return 'j';
    if (scancode == 0x25) return 'k';
    if (scancode == 0x26) return 'l';

    // Tercera fila de letras (ZXCVB)
    if (scancode == 0x2C) return 'z';
    if (scancode == 0x2D) return 'x';
    if (scancode == 0x2E) return 'c';
    if (scancode == 0x2F) return 'v';
    if (scancode == 0x30) return 'b';
    if (scancode == 0x31) return 'n';
    if (scancode == 0x32) return 'm';

    // Espacio y otros caracteres especiales
    if (scancode == 0x39) return ' ';

    // Si no se reconoce el scancode, retornamos 0
    return 0;
}

// Comparar dos cadenas
int strcmp(const char* s1, const char* s2) {
    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return *(unsigned char*)s1 - *(unsigned char*)s2;
}

// Procesador de comandos
void process_command(char* cmd) {
    // Eliminar espacios iniciales
    while (*cmd == ' ') cmd++;

    // Detectar el comando
    int command_type = CMD_UNKNOWN;
    char* arg_start = cmd;

    // Buscar el primer espacio (separador entre comando y argumentos)
    while (*arg_start && *arg_start != ' ') arg_start++;

    // Si hay espacio, lo reemplazamos con nulo para separar el comando de los argumentos
    if (*arg_start == ' ') {
        *arg_start = '\0';
        arg_start++;
    } else {
        arg_start = NULL; // No hay argumentos
    }

    // Determinar el tipo de comando
    if (strcmp(cmd, "process") == 0) {
        command_type = CMD_PROCESS;
    } else if (strcmp(cmd, "help") == 0) {
        command_type = CMD_HELP;
    } else if (strcmp(cmd, "clear") == 0) {
        command_type = CMD_CLEAR;
    } else if (strcmp(cmd, "exit") == 0) {
        command_type = CMD_EXIT;
    }

    // Procesar el comando según su tipo
    switch (command_type) {
        case CMD_PROCESS:
            if (!arg_start) {
                print(CONSOLE_START_X, cursor_y, "Uso: process -l|-k|-r [pid|nombre]", 0x0C);
                cursor_y++;
                break;
            }

            // Extraer la opción (-l, -k, -r)
            char option[3] = {0};
            char* target = NULL;

            // Extraer la opción
            if (arg_start[0] == '-' && arg_start[1]) {
                option[0] = '-';
                option[1] = arg_start[1];
                option[2] = '\0';

                // Buscar el objetivo después de la opción
                char* opt_end = arg_start + 2;
                while (*opt_end == ' ') opt_end++;

                if (*opt_end) {
                    target = opt_end;
                }
            }

            if (strcmp(option, "-l") == 0) {
                // Listar procesos activos
                print(CONSOLE_START_X, cursor_y, "Procesos activos (PID, Nombre, Estado):", CONSOLE_PROMPT_COLOR);
                cursor_y++;

                for (uint8_t i = 0; i < process_count; i++) {
                    char pid_str[4];
                    uint64_to_dec(i, pid_str);

                    print(CONSOLE_START_X + 2, cursor_y, pid_str, CONSOLE_TEXT_COLOR);
                    print(CONSOLE_START_X + 6, cursor_y, processes[i].name, CONSOLE_TEXT_COLOR);

                    if (processes[i].status == PROCESS_RUNNING) {
                        print(CONSOLE_START_X + 25, cursor_y, "Activo", 0x0A); // Verde para activo
                    } else {
                        print(CONSOLE_START_X + 25, cursor_y, "Detenido", 0x0C); // Rojo para detenido
                    }

                    cursor_y++;
                }
            } else if (strcmp(option, "-k") == 0) {
                // Matar proceso por PID o nombre
                if (!target) {
                    print(CONSOLE_START_X, cursor_y, "Error: Debes especificar un PID o nombre de proceso", 0x0C);
                    cursor_y++;
                    break;
                }

                // Verificar si es un PID (número)
                uint8_t is_pid = 1;
                for (int i = 0; target[i]; i++) {
                    if (target[i] < '0' || target[i] > '9') {
                        is_pid = 0;
                        break;
                    }
                }

                if (is_pid) {
                    // Convertir string a número
                    uint8_t pid = 0;
                    for (int i = 0; target[i]; i++) {
                        pid = pid * 10 + (target[i] - '0');
                    }

                    if (pid < process_count) {
                        if (processes[pid].status == PROCESS_RUNNING) {
                            kill_process(pid);
                            print(CONSOLE_START_X, cursor_y, "Proceso detenido: ", CONSOLE_TEXT_COLOR);
                            print(CONSOLE_START_X + 17, cursor_y, processes[pid].name, 0x0A);
                        } else {
                            print(CONSOLE_START_X, cursor_y, "El proceso ya está detenido: ", CONSOLE_TEXT_COLOR);
                            print(CONSOLE_START_X + 28, cursor_y, processes[pid].name, 0x0C);
                        }
                    } else {
                        print(CONSOLE_START_X, cursor_y, "Error: PID inválido", 0x0C);
                    }
                } else {
                    // Buscar por nombre
                    uint8_t found = 0;
                    for (uint8_t i = 0; i < process_count; i++) {
                        if (strcmp(processes[i].name, target) == 0) {
                            if (processes[i].status == PROCESS_RUNNING) {
                                kill_process(i);
                                print(CONSOLE_START_X, cursor_y, "Proceso detenido: ", CONSOLE_TEXT_COLOR);
                                print(CONSOLE_START_X + 17, cursor_y, processes[i].name, 0x0A);
                            } else {
                                print(CONSOLE_START_X, cursor_y, "El proceso ya está detenido: ", CONSOLE_TEXT_COLOR);
                                print(CONSOLE_START_X + 28, cursor_y, processes[i].name, 0x0C);
                            }
                            found = 1;
                            break;
                        }
                    }

                    if (!found) {
                        print(CONSOLE_START_X, cursor_y, "Error: Proceso no encontrado: ", CONSOLE_TEXT_COLOR);
                        print(CONSOLE_START_X + 31, cursor_y, target, 0x0C);
                    }
                }
                cursor_y++;
            } else if (strcmp(option, "-r") == 0) {
                // Reanudar proceso por PID o nombre
                if (!target) {
                    print(CONSOLE_START_X, cursor_y, "Error: Debes especificar un PID o nombre de proceso", 0x0C);
                    cursor_y++;
                    break;
                }

                // Verificar si es un PID (número)
                uint8_t is_pid = 1;
                for (int i = 0; target[i]; i++) {
                    if (target[i] < '0' || target[i] > '9') {
                        is_pid = 0;
                        break;
                    }
                }

                if (is_pid) {
                    // Convertir string a número
                    uint8_t pid = 0;
                    for (int i = 0; target[i]; i++) {
                        pid = pid * 10 + (target[i] - '0');
                    }

                    if (pid < process_count) {
                        if (processes[pid].status == PROCESS_STOPPED) {
                            processes[pid].status = PROCESS_RUNNING;
                            active_processes++;
                            print(CONSOLE_START_X, cursor_y, "Proceso reanudado: ", CONSOLE_TEXT_COLOR);
                            print(CONSOLE_START_X + 19, cursor_y, processes[pid].name, 0x0A);
                        } else {
                            print(CONSOLE_START_X, cursor_y, "El proceso ya está activo: ", CONSOLE_TEXT_COLOR);
                            print(CONSOLE_START_X + 27, cursor_y, processes[pid].name, 0x0C);
                        }
                    } else {
                        print(CONSOLE_START_X, cursor_y, "Error: PID inválido", 0x0C);
                    }
                } else {
                    // Buscar por nombre
                    uint8_t found = 0;
                    for (uint8_t i = 0; i < process_count; i++) {
                        if (strcmp(processes[i].name, target) == 0) {
                            if (processes[i].status == PROCESS_STOPPED) {
                                processes[i].status = PROCESS_RUNNING;
                                active_processes++;
                                print(CONSOLE_START_X, cursor_y, "Proceso reanudado: ", CONSOLE_TEXT_COLOR);
                                print(CONSOLE_START_X + 19, cursor_y, processes[i].name, 0x0A);
                            } else {
                                print(CONSOLE_START_X, cursor_y, "El proceso ya está activo: ", CONSOLE_TEXT_COLOR);
                                print(CONSOLE_START_X + 27, cursor_y, processes[i].name, 0x0C);
                            }
                            found = 1;
                            break;
                        }
                    }

                    if (!found) {
                        print(CONSOLE_START_X, cursor_y, "Error: Proceso no encontrado: ", CONSOLE_TEXT_COLOR);
                        print(CONSOLE_START_X + 31, cursor_y, target, 0x0C);
                    }
                }
                cursor_y++;
            } else {
                print(CONSOLE_START_X, cursor_y, "Uso: process -l|-k|-r [pid|nombre]", 0x0C);
                cursor_y++;
            }
            break;

        case CMD_HELP:
            print(CONSOLE_START_X, cursor_y, "Comandos disponibles:", CONSOLE_PROMPT_COLOR);
            cursor_y++;
            print(CONSOLE_START_X + 2, cursor_y, "process -l        : Listar procesos activos", CONSOLE_TEXT_COLOR);
            cursor_y++;
            print(CONSOLE_START_X + 2, cursor_y, "process -k pid/nom: Detener un proceso específico", CONSOLE_TEXT_COLOR);
            cursor_y++;
            print(CONSOLE_START_X + 2, cursor_y, "process -r pid/nom: Iniciar/reanudar un proceso", CONSOLE_TEXT_COLOR);
            cursor_y++;
            print(CONSOLE_START_X + 2, cursor_y, "clear             : Limpiar pantalla", CONSOLE_TEXT_COLOR);
            cursor_y++;
            print(CONSOLE_START_X + 2, cursor_y, "help              : Mostrar esta ayuda", CONSOLE_TEXT_COLOR);
            cursor_y++;
            print(CONSOLE_START_X + 2, cursor_y, "exit              : Salir de Portal Shell", CONSOLE_TEXT_COLOR);
            cursor_y++;
            print(CONSOLE_START_X + 2, cursor_y, "version           : Mostrar version de Portal", CONSOLE_TEXT_COLOR);
            cursor_y++;
            print(CONSOLE_START_X + 2, cursor_y, "about             : Informacion sobre Portal Shell", CONSOLE_TEXT_COLOR);
            cursor_y++;
            break;

        case CMD_CLEAR:
            clear_region(CONSOLE_START_Y + 1, CONSOLE_END_Y, CONSOLE_TEXT_COLOR);
            cursor_y = CONSOLE_START_Y + 1;
            break;

        case CMD_EXIT:
            print(CONSOLE_START_X, cursor_y, "Saliendo de Portal Shell...", CONSOLE_PROMPT_COLOR);
            cursor_y++;
            portal_command_ready = -1;  // Señal especial para salir
            break;

        default:
            print(CONSOLE_START_X, cursor_y, "Comando desconocido. Escribe 'help' para ver comandos disponibles.", 0x0C);
            cursor_y++;
            break;
    }

    // Avanzar la línea si estamos cerca del límite
    if (cursor_y >= CONSOLE_END_Y) {
        cursor_y = CONSOLE_START_Y + 1;
        clear_region(CONSOLE_START_Y + 1, CONSOLE_END_Y, CONSOLE_TEXT_COLOR);
    }
}

// Actualizar el contador de tiempo (timestamp)
void update_timestamp() {
    // Incrementar segundos y manejar el desbordamiento
    if (++seconds >= 60) {
        seconds = 0;
        if (++minutes >= 60) {
            minutes = 0;
            if (++hours >= 24) {
                hours = 0;
            }
        }
    }

    // Convertir a strings con formato
    char h_str[3], m_str[3], s_str[3];
    uint8_to_dec_padded(hours, h_str);
    uint8_to_dec_padded(minutes, m_str);
    uint8_to_dec_padded(seconds, s_str);

    // Mostrar en pantalla (movido a la derecha)
    print(60, CONSOLE_FOOTER_LINE, "Tiempo: ", 0x07);
    print(68, CONSOLE_FOOTER_LINE, h_str, 0x0E);
    putchar(70, CONSOLE_FOOTER_LINE, ':', 0x07);
    print(71, CONSOLE_FOOTER_LINE, m_str, 0x0E);
    putchar(73, CONSOLE_FOOTER_LINE, ':', 0x07);
    print(74, CONSOLE_FOOTER_LINE, s_str, 0x0E);
}

// Funciones para el sistema de procesos
uint8_t create_process(char* name, void (*function)(uint64_t)) {
    if (process_count >= MAX_PROCESSES) return 0;

    uint8_t pid = process_count++;
    Process* proc = &processes[pid];

    proc->id = pid;
    proc->status = PROCESS_RUNNING;

    // Copiar nombre con seguridad
    for (int i = 0; i < 15 && name[i]; i++) {
        proc->name[i] = name[i];
    }
    proc->name[15] = '\0';

    proc->ticks = 0;
    proc->function = function;

    active_processes++;

    return pid;
}

void kill_process(uint8_t pid) {
    if (pid >= process_count) return;

    if (processes[pid].status == PROCESS_RUNNING) {
        // Limpieza visual según el tipo de proceso
        if (strcmp(processes[pid].name, "RAMMonitor") == 0) {
            // Limpiar área de RAMMonitor
            for (int i = 0; i < 15; i++) {
                putchar(FOOTER_RAMUSE_POS + i, CONSOLE_FOOTER_LINE, '-', 0x07);
            }
        } else if (strcmp(processes[pid].name, "ProcessCounter") == 0) {
            // Limpiar área del contador de procesos
            for (int i = 0; i < 15; i++) {
                putchar(FOOTER_PROCS_POS + i, CONSOLE_FOOTER_LINE, '-', 0x07);
            }
        }

        processes[pid].status = PROCESS_STOPPED;
        active_processes--;
    }
}

void run_processes(void) {
    for (uint8_t i = 0; i < process_count; i++) {
        if (processes[i].status == PROCESS_RUNNING) {
            processes[i].function(processes[i].ticks++);
        }
    }
}

// Proceso 1: Heartbeat
void process_heartbeat(uint64_t ticks) {
    char heartbeat[] = {'|', '/', '-', '\\'};
    putchar(79, CONSOLE_FOOTER_LINE, heartbeat[ticks % 4], 0x0E);
}

// Proceso 2: Contador de segundos basado en PIT
void process_counter(uint64_t ticks) {
    static uint64_t last_second = 0;

    // Verificar si ha pasado un segundo (50 ticks ahora)
    if (pit_ticks >= last_second + PIT_TICKS_PER_SECOND) {
        last_second = pit_ticks;
        update_timestamp();
    }
}

// Proceso 3: Monitor de RAM
void process_rammonitor(uint64_t ticks) {
    static uint64_t last_update = 0;

    // Actualizar cada segundo (50 ticks)
    if (ticks - last_update >= PIT_TICKS_PER_SECOND) {
        last_update = ticks;

        // Limpiar el área primero en todos los casos
        for (int i = 0; i < 15; i++) {
            putchar(FOOTER_RAMUSE_POS + i, CONSOLE_FOOTER_LINE, '-', 0x07);
        }

        // Solo mostrar la información si el proceso está activo
        // (aunque esta verificación es redundante ya que esta función
        // solo se llama si el proceso está activo)
        for (uint8_t i = 0; i < process_count; i++) {
            if (strcmp(processes[i].name, "RAMMonitor") == 0 &&
                processes[i].status == PROCESS_RUNNING) {
                // Mostrar información de RAM
                char ram_str[8];
                uint64_to_dec(mapped_memory_mb, ram_str);

                // Mostrar información actualizada
                print(FOOTER_RAMUSE_POS, CONSOLE_FOOTER_LINE, "RAM:", 0x07);
                print(FOOTER_RAMUSE_POS + 5, CONSOLE_FOOTER_LINE, ram_str, 0x0B);
                print(FOOTER_RAMUSE_POS + 8, CONSOLE_FOOTER_LINE, "MB", 0x07);
                break;
            }
        }
    }
}

// Proceso 4: Monitor de Procesos
void process_procmonitor(uint64_t ticks) {
    static uint64_t last_update = 0;
    static uint8_t last_process_count = 0;

    // Actualizar cada segundo (50 ticks)
    if (ticks - last_update >= PIT_TICKS_PER_SECOND || last_process_count != active_processes) {
        last_update = ticks;
        last_process_count = active_processes;

        // Limpiar el área anterior
        for (int i = 0; i < 15; i++) {
            putchar(FOOTER_PROCS_POS + i, CONSOLE_FOOTER_LINE, '-', 0x07);
        }

        // Mostrar conteo de procesos
        char proc_str[4];
        uint64_to_dec(active_processes, proc_str);
        print(FOOTER_PROCS_POS, CONSOLE_FOOTER_LINE, "Proc:", 0x07);
        print(FOOTER_PROCS_POS + 6, CONSOLE_FOOTER_LINE, proc_str, 0x0A);

        // Mostrar de total/activos
        char total_str[4];
        uint64_to_dec(process_count, total_str);
        putchar(FOOTER_PROCS_POS + 8, CONSOLE_FOOTER_LINE, '/', 0x07);
        print(FOOTER_PROCS_POS + 9, CONSOLE_FOOTER_LINE, total_str, 0x0E);
    }
}

// Proceso 5: Segundo Heartbeat
void process_heartbeat2(uint64_t ticks) {
    char heartbeat[] = {'<', '/', '-', '\\'};  // Usar caracteres ASCII estándar

    // Determinar color basado en la posición del ciclo
    uint8_t color = 0x0C; // Color rojo por defecto

    switch (ticks % 4) {
        case 0: color = 0x0C; break; // Rojo (corazón)
        case 1: color = 0x0D; break; // Magenta (diamante)
        case 2: color = 0x0A; break; // Verde (trébol)
        case 3: color = 0x0F; break; // Blanco brillante (pica)
    }

    // Limpiar área
    for (int i = 0; i < 5; i++) {
        putchar(FOOTER_HEARTBEAT2_POS + i, CONSOLE_FOOTER_LINE, '-', 0x07);
    }

    // Mostrar símbolo con color apropiado
    putchar(FOOTER_HEARTBEAT2_POS, CONSOLE_FOOTER_LINE, '<', 0x07);
    putchar(FOOTER_HEARTBEAT2_POS + 1, CONSOLE_FOOTER_LINE, heartbeat[ticks % 4], color);
    putchar(FOOTER_HEARTBEAT2_POS + 2, CONSOLE_FOOTER_LINE, '>', 0x07);
}

// Proceso dedicado para la Shell Portal
void process_portal(uint64_t ticks) {
    static int portal_initialized = 0;
    static int exit_requested = 0;

    // Inicializar Portal si es la primera vez
    if (!portal_initialized) {
        portal_init();
        portal_initialized = 1;
        print(CONSOLE_START_X, CONSOLE_STATUS_LINE, "Estado: Portal Shell activo", 0x0A);  // Mensaje más simple
    }

    // Verificar si hay una señal para salir de Portal
    if (portal_command_ready == -1) {
        // Marcar que se solicitó salir para limpieza posterior
        exit_requested = 1;
        // Restablecer la bandera
        portal_command_ready = 0;

        // Mostrar mensaje de salida en la línea actual
        print(CONSOLE_START_X, cursor_y, "Saliendo del intérprete de comandos Portal...", CONSOLE_PROMPT_COLOR);
        cursor_y++;

        // Restaurar título de la consola básica sin limpiar toda la pantalla
        print(CONSOLE_START_X, CONSOLE_START_Y, "Shell Portal disponible, escriba 'portal' para ingresar a la shell", CONSOLE_PROMPT_COLOR);

        // También actualizamos la línea de estado para ser consistentes
        print(0, CONSOLE_STATUS_LINE, "                                                                                ", 0x07);

        // Posicionar el cursor para el siguiente prompt
        if (cursor_y >= CONSOLE_END_Y) {
            cursor_y = CONSOLE_START_Y + 1;
        }

        // Nuevo prompt
        print(CONSOLE_START_X, cursor_y, "> ", CONSOLE_PROMPT_COLOR);
        buffer_position = 0;
        input_buffer[0] = '\0';
        set_cursor(CONSOLE_START_X + 2, cursor_y);

        // Detener este proceso
        for (uint8_t i = 0; i < process_count; i++) {
            if (strcmp(processes[i].name, "Portal") == 0) {
                kill_process(i);
                // Reiniciar el estado para la próxima ejecución
                portal_initialized = 0;
                exit_requested = 0;
                break;
            }
        }
        return;
    }

    // Verificar si hay un comando para procesar (solo si no estamos saliendo)
    if (!exit_requested && portal_command_ready) {
        // Copiar el comando del buffer compartido
        int i;
        for (i = 0; i < MAX_COMMAND_LENGTH && portal_command_buffer[i]; i++) {
            command_buffer[i] = portal_command_buffer[i];
        }
        command_buffer[i] = '\0';

        // Limpiar bandera
        portal_command_ready = 0;

        // Crear estructura de comando y ejecutarlo
        PortalCommand cmd;
        portal_parse_command(command_buffer, &cmd);
        portal_execute_command(&cmd);

        // Mostrar nuevo prompt después de procesar
        if (cursor_y >= CONSOLE_END_Y) {
            cursor_y = CONSOLE_START_Y + 1;
            clear_region(CONSOLE_START_Y + 1, CONSOLE_END_Y, CONSOLE_TEXT_COLOR);
        }
        portal_print_prompt();
    }
}

// Declaración adelantada para pit_tick
void pit_tick(void);

// Función para enviar un comando desde la consola a Portal
void send_to_portal(char* command) {
    // Copiar el comando al buffer compartido
    int i;
    for (i = 0; i < MAX_COMMAND_LENGTH && command[i]; i++) {
        portal_command_buffer[i] = command[i];
    }
    portal_command_buffer[i] = '\0';

    // Señalizar que hay un comando listo
    portal_command_ready = 1;
}

// Proceso de consola (modificado para comunicarse con Portal)
void process_console(uint64_t ticks) {
    // Variables estáticas para tracking del estado de Portal
    static int last_key_check = 0;
    static int last_portal_check = 0;
    static int portal_running = 0;
    static int portal_process_id = -1;
    static int last_portal_status = 0;

    // Verificar si hay una tecla presionada cada cierto número de ticks
    if (ticks - last_key_check >= 2) { // Reducir la frecuencia de verificación
        last_key_check = ticks;

        if (inb(0x64) & 1) {
            uint8_t scancode = inb(0x60);
            process_key(scancode);
        }
    }

    // Verificar si Portal tiene un comando listo para procesar
    if (ticks - last_portal_check >= 5) {
        last_portal_check = ticks;

        // Verificar si Portal está aún activo
        int current_portal_status = 0;

        // Encontrar el proceso Portal actual y verificar su estado
        portal_process_id = -1; // Restablecer para buscar de nuevo
        for (uint8_t i = 0; i < process_count; i++) {
            if (strcmp(processes[i].name, "Portal") == 0) {
                portal_process_id = i;
                current_portal_status = (processes[i].status == PROCESS_RUNNING);
                break;
            }
        }

        // Si Portal acaba de ser detenido (por process -k por ejemplo)
        if (portal_running && !current_portal_status) {
            // Restaurar interfaz a consola básica
            print(CONSOLE_START_X, CONSOLE_START_Y, "Shell Portal disponible, escriba 'portal' para ingresar a la shell", CONSOLE_PROMPT_COLOR);
            //print(0, CONSOLE_STATUS_LINE, "Estado: Consola basica activa - Escribe 'portal' para iniciar la shell", 0x0E);

            // Si el cursor está en posición inválida, reposicionarlo
            if (cursor_y < CONSOLE_START_Y + 1 || cursor_y >= CONSOLE_END_Y) {
                cursor_y = CONSOLE_START_Y + 1;
            }

            // Nuevo prompt en la posición actual
            print(CONSOLE_START_X, cursor_y, "> ", CONSOLE_PROMPT_COLOR);
            buffer_position = 0;
            input_buffer[0] = '\0';
            set_cursor(CONSOLE_START_X + 2, cursor_y);

            // Actualizar el estado global para que process_key también sepa que Portal ya no está activo
            portal_running = 0;
        }

        // Actualizar el estado de Portal
        portal_running = current_portal_status;
        last_portal_status = current_portal_status;

        // Si Portal está inactivo, no procesar comandos destinados a él
        if (portal_command_ready && !portal_running) {
            portal_command_ready = 0; // Limpiar la bandera si Portal no está activo
        }
        // Si está activo y hay comandos, procesarlos
        else if (portal_command_ready && portal_running) {
            // Copiar el comando del buffer compartido
            int i;
            for (i = 0; i < MAX_COMMAND_LENGTH && portal_command_buffer[i]; i++) {
                command_buffer[i] = portal_command_buffer[i];
            }
            command_buffer[i] = '\0';

            // Limpiar bandera
            portal_command_ready = 0;

            // Enviar comando para procesar en Portal
            send_to_portal(command_buffer);
        }
    }
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
    
    // Inicializar sistema de procesos
    for (int i = 0; i < MAX_PROCESSES; i++) {
        processes[i].status = PROCESS_STOPPED;
    }
    process_count = 0;
    active_processes = 0;

    // Inicializar el temporizador
    init_pit(PIT_TICKS_PER_SECOND);

    // Crear procesos iniciales - Portal no se inicia automáticamente
    create_process("Console", process_console);
    create_process("Heartbeat", process_heartbeat);
    create_process("Counter", process_counter);

    // Crear los nuevos procesos de monitorización para la línea de footer
    create_process("RAMMonitor", process_rammonitor);
    create_process("ProcMonitor", process_procmonitor);
    create_process("Heartbeat2", process_heartbeat2);

    // Mostrar información técnica
    char mem_str[32];
    char mapped_mem_str[32];
    char proc_str[8];
    uint64_t memory = detect_memory();
    uint64_to_hex(memory, mem_str);
    uint64_to_dec(mapped_memory_mb, mapped_mem_str);
    uint64_to_dec(active_processes, proc_str);

    print(0, 7, "Informacion del Sistema:", 0x0B);
    print(2, 8, "- Arquitectura: x86_64", 0x07);
    print(2, 9, "- Memoria detectada: ", 0x07);
    print(22, 9, mem_str, 0x0E);
    print(2, 10, "- Memoria mapeada: ", 0x07);
    print(22, 10, mapped_mem_str, 0x0E);
    print(26, 10, " MB", 0x07);
    print(2, 11, "- Procesos activos: ", 0x07);
    print(22, 11, proc_str, 0x0E);

    // Línea divisoria
    print(0, 12, "-------------------------------------------------------------------------------", 0x07);

    // Inicializar la consola básica
    init_console();

    // Status bar
    //print(0, CONSOLE_STATUS_LINE, "Estado: Consola basica activa - Escribe 'portal' para iniciar la shell", 0x0E);
    print(0, CONSOLE_STATUS_LINE + 1, "-------------------------------------------------------------------------------", 0x07);

    // Footer con timestamp y heartbeat - Ahora movido a la derecha
    print(60, CONSOLE_FOOTER_LINE, "Tiempo: ", 0x07);
    update_timestamp(); // Actualizar inmediatamente para mostrar 00:00:00

    // Bucle principal del kernel
    uint64_t counter = 0;

    while(1) {
        // Simulamos un tick del PIT cada iteración del bucle
        pit_tick();

        // Ejecutar todos los procesos activos
        run_processes();

        // Retardo usando contador de 64 bits (ajustado para simular unos 20ms por iteración)
        for (volatile uint64_t i = 0; i < 2500000ULL; i++) { }

        counter++;
    }
}

// Inicializa la shell Portal
void portal_init(void) {
    // Limpiamos el área de consola pero preservamos el título
    clear_region(CONSOLE_START_Y + 1, CONSOLE_END_Y, CONSOLE_TEXT_COLOR);

    // Cambiamos el título fijo por el título de Portal activado
    clear_region(CONSOLE_START_Y, CONSOLE_START_Y, CONSOLE_TEXT_COLOR);
    print(CONSOLE_START_X, CONSOLE_START_Y, "Shell Portal v" PORTAL_VERSION " - escriba 'help' para obtener ayuda", CONSOLE_PROMPT_COLOR);

    // Inicializamos el cursor justo debajo del título (eliminada la línea de bienvenida)
    cursor_y = CONSOLE_START_Y + 1; // Una línea más cercana al título (eliminada la bienvenida)
    portal_print_prompt();
    buffer_position = 0;
    input_buffer[0] = '\0';
    set_cursor(CONSOLE_START_X + 2, cursor_y);
}

// Muestra el mensaje de bienvenida de Portal
void portal_display_welcome(void) {
    print(CONSOLE_START_X, CONSOLE_START_Y + 1, "Bienvenido a Portal Shell. Escribe 'help' para ver comandos disponibles.", 0x07);
}

// Imprime el prompt de la shell Portal
void portal_print_prompt(void) {
    print(CONSOLE_START_X, cursor_y, PORTAL_PROMPT, CONSOLE_PROMPT_COLOR);
    buffer_position = 0;
    input_buffer[0] = '\0';
    set_cursor(CONSOLE_START_X + 2, cursor_y);
}

// Divide un comando en partes (comando y argumentos)
void portal_parse_command(char* input, PortalCommand* cmd) {
    // Limpiar la estructura de comando
    cmd->argc = 0;

    // Eliminar espacios iniciales
    while (*input == ' ') input++;

    // Si no hay comando, salimos
    if (*input == '\0') {
        cmd->command[0] = '\0';
        return;
    }

    // Copiar el comando completo para referencia
    int i;
    for (i = 0; i < MAX_COMMAND_LENGTH && input[i]; i++) {
        cmd->command[i] = input[i];
    }
    cmd->command[i] = '\0';

    // Obtener el primer token (comando)
    for (i = 0; i < MAX_COMMAND_LENGTH && input[i] && input[i] != ' '; i++) {
        cmd->args[0][i] = input[i];
    }
    cmd->args[0][i] = '\0';
    cmd->argc = 1;

    // Buscar el primer espacio
    char* space = input;
    while (*space && *space != ' ') space++;

    // Si no hay espacio, no hay argumentos
    if (*space == '\0') {
        return;
    }

    // Marcar el fin del comando (ahora trabajamos con una copia)
    *space = '\0';

    // Procesar los argumentos
    char* token = space + 1;

    // Saltear espacios iniciales
    while (*token == ' ') token++;

    // Si no hay más caracteres, podría haber más argumentos
    if (*token != '\0') {
        // El siguiente token es el primer argumento
        i = 0;
        while (*token && *token != ' ' && i < MAX_COMMAND_LENGTH) {
            cmd->args[1][i++] = *token++;
        }
        cmd->args[1][i] = '\0';
        cmd->argc = 2;
    }

    // Si hay más texto después, podría haber más argumentos
    if (*token == ' ') {
        // Procesar argumentos adicionales (a partir del tercero)
        int arg_idx = 2;

        while (*token && arg_idx < PORTAL_MAX_ARGS) {
            // Saltar espacios
            while (*token == ' ') token++;

            // Si llegamos al final, salir
            if (*token == '\0') break;

            // Guardar el argumento
            i = 0;
            while (*token && *token != ' ' && i < MAX_COMMAND_LENGTH) {
                cmd->args[arg_idx][i++] = *token++;
            }
            cmd->args[arg_idx][i] = '\0';
            arg_idx++;

            // Si encontramos un espacio, continuar con el siguiente argumento
            if (*token == ' ') {
                token++;
            }
        }

        cmd->argc = arg_idx;
    }
}

// Ejecuta un comando procesado de Portal
int portal_execute_command(PortalCommand* cmd) {
    // Si no hay comando, no hacemos nada
    if (cmd->argc == 0 || !cmd->args[0]) {
        return 0;
    }

    // Comandos básicos del sistema
    if (strcmp(cmd->args[0], "clear") == 0) {
        clear_region(CONSOLE_START_Y + 1, CONSOLE_END_Y, CONSOLE_TEXT_COLOR);
        cursor_y = CONSOLE_START_Y + 1;
        return 1;
    }

    if (strcmp(cmd->args[0], "help") == 0) {
        // Limpiamos primero para asegurar que hay espacio suficiente
        clear_region(CONSOLE_START_Y + 1, CONSOLE_END_Y, CONSOLE_TEXT_COLOR);
        cursor_y = CONSOLE_START_Y + 1;

        print(CONSOLE_START_X, cursor_y, "Comandos de Portal Shell:", CONSOLE_PROMPT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X + 2, cursor_y, "process -l        : Listar procesos activos", CONSOLE_TEXT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X + 2, cursor_y, "process -k pid/nom: Detener un proceso específico", CONSOLE_TEXT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X + 2, cursor_y, "process -r pid/nom: Iniciar/reanudar un proceso", CONSOLE_TEXT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X + 2, cursor_y, "clear             : Limpiar pantalla", CONSOLE_TEXT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X + 2, cursor_y, "help              : Mostrar esta ayuda", CONSOLE_TEXT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X + 2, cursor_y, "exit              : Salir de Portal Shell", CONSOLE_TEXT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X + 2, cursor_y, "version           : Mostrar version de Portal", CONSOLE_TEXT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X + 2, cursor_y, "about             : Informacion sobre Portal Shell", CONSOLE_TEXT_COLOR);
        cursor_y++;
        return 1;
    }

    if (strcmp(cmd->args[0], "version") == 0) {
        print(CONSOLE_START_X, cursor_y, "Portal Shell versión " PORTAL_VERSION, CONSOLE_PROMPT_COLOR);
        cursor_y++;
        return 1;
    }

    if (strcmp(cmd->args[0], "about") == 0) {
        print(CONSOLE_START_X, cursor_y, "Portal Shell v" PORTAL_VERSION " - MoonlightOS", CONSOLE_PROMPT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X, cursor_y, "Desarrollado por Moonlight-Pawling como parte del sistema MoonlightOS", CONSOLE_TEXT_COLOR);
        cursor_y++;
        return 1;
    }

    if (strcmp(cmd->args[0], "exit") == 0) {
        print(CONSOLE_START_X, cursor_y, "Saliendo de Portal Shell...", CONSOLE_PROMPT_COLOR);
        cursor_y++;
        portal_command_ready = -1;  // Señal especial para salir
        return 1;
    }

    if (strcmp(cmd->args[0], "process") == 0) {
        // Verificar opciones de proceso
        if (cmd->argc < 2) {
            print(CONSOLE_START_X, cursor_y, "Uso: process -l|-k|-r [pid|nombre]", 0x0C);
            cursor_y++;
            return 1;
        }

        // Comando process -l
        if (strcmp(cmd->args[1], "-l") == 0) {
            print(CONSOLE_START_X, cursor_y, "Procesos activos (PID, Nombre, Estado):", CONSOLE_PROMPT_COLOR);
            cursor_y++;

            // Asegurar que hay suficiente espacio para mostrar la lista
            if (cursor_y + process_count >= CONSOLE_END_Y) {
                clear_region(CONSOLE_START_Y + 1, CONSOLE_END_Y, CONSOLE_TEXT_COLOR);
                cursor_y = CONSOLE_START_Y + 1;
                print(CONSOLE_START_X, cursor_y, "Procesos activos (PID, Nombre, Estado):", CONSOLE_PROMPT_COLOR);
                cursor_y++;
            }

            for (uint8_t i = 0; i < process_count; i++) {
                char pid_str[4];
                uint64_to_dec(i, pid_str);

                print(CONSOLE_START_X + 2, cursor_y, pid_str, CONSOLE_TEXT_COLOR);
                print(CONSOLE_START_X + 6, cursor_y, processes[i].name, CONSOLE_TEXT_COLOR);

                if (processes[i].status == PROCESS_RUNNING) {
                    print(CONSOLE_START_X + 25, cursor_y, "Activo", 0x0A); // Verde para activo
                } else {
                    print(CONSOLE_START_X + 25, cursor_y, "Detenido", 0x0C); // Rojo para detenido
                }
                cursor_y++;
            }
            return 1;
        }

        // Comando process -k (matar proceso)
        if (strcmp(cmd->args[1], "-k") == 0) {
            if (cmd->argc < 3) {
                print(CONSOLE_START_X, cursor_y, "Error: Debes especificar un PID o nombre de proceso", 0x0C);
                cursor_y++;
                return 1;
            }

            char* target = cmd->args[2];

            // Verificar si es un PID (número)
            uint8_t is_pid = 1;
            for (int i = 0; target[i]; i++) {
                if (target[i] < '0' || target[i] > '9') {
                    is_pid = 0;
                    break;
                }
            }

            if (is_pid) {
                // Convertir string a número
                uint8_t pid = 0;
                for (int i = 0; target[i]; i++) {
                    pid = pid * 10 + (target[i] - '0');
                }

                if (pid < process_count) {
                    if (processes[pid].status == PROCESS_RUNNING) {
                        kill_process(pid);
                        print(CONSOLE_START_X, cursor_y, "Proceso detenido: ", CONSOLE_TEXT_COLOR);
                        print(CONSOLE_START_X + 17, cursor_y, processes[pid].name, 0x0A);
                    } else {
                        print(CONSOLE_START_X, cursor_y, "El proceso ya está detenido: ", CONSOLE_TEXT_COLOR);
                        print(CONSOLE_START_X + 28, cursor_y, processes[pid].name, 0x0C);
                    }
                } else {
                    print(CONSOLE_START_X, cursor_y, "Error: PID inválido", 0x0C);
                }
            } else {
                // Buscar por nombre
                uint8_t found = 0;
                for (uint8_t i = 0; i < process_count; i++) {
                    if (strcmp(processes[i].name, target) == 0) {
                        if (processes[i].status == PROCESS_RUNNING) {
                            kill_process(i);
                            print(CONSOLE_START_X, cursor_y, "Proceso detenido: ", CONSOLE_TEXT_COLOR);
                            print(CONSOLE_START_X + 17, cursor_y, processes[i].name, 0x0A);
                        } else {
                            print(CONSOLE_START_X, cursor_y, "El proceso ya está detenido: ", CONSOLE_TEXT_COLOR);
                            print(CONSOLE_START_X + 28, cursor_y, processes[i].name, 0x0C);
                        }
                        found = 1;
                        break;
                    }
                }

                if (!found) {
                    print(CONSOLE_START_X, cursor_y, "Error: Proceso no encontrado: ", CONSOLE_TEXT_COLOR);
                    print(CONSOLE_START_X + 31, cursor_y, target, 0x0C);
                }
            }
            cursor_y++;
            return 1;
        }

        // Comando process -r (reanudar proceso)
        if (strcmp(cmd->args[1], "-r") == 0) {
            if (cmd->argc < 3) {
                print(CONSOLE_START_X, cursor_y, "Error: Debes especificar un PID o nombre de proceso", 0x0C);
                cursor_y++;
                return 1;
            }

            char* target = cmd->args[2];

            // Verificar si es un PID (número)
            uint8_t is_pid = 1;
            for (int i = 0; target[i]; i++) {
                if (target[i] < '0' || target[i] > '9') {
                    is_pid = 0;
                    break;
                }
            }

            if (is_pid) {
                // Convertir string a número
                uint8_t pid = 0;
                for (int i = 0; target[i]; i++) {
                    pid = pid * 10 + (target[i] - '0');
                }

                if (pid < process_count) {
                    if (processes[pid].status == PROCESS_STOPPED) {
                        processes[pid].status = PROCESS_RUNNING;
                        active_processes++;
                        print(CONSOLE_START_X, cursor_y, "Proceso reanudado: ", CONSOLE_TEXT_COLOR);
                        print(CONSOLE_START_X + 19, cursor_y, processes[pid].name, 0x0A);
                    } else {
                        print(CONSOLE_START_X, cursor_y, "El proceso ya está activo: ", CONSOLE_TEXT_COLOR);
                        print(CONSOLE_START_X + 27, cursor_y, processes[pid].name, 0x0C);
                    }
                } else {
                    print(CONSOLE_START_X, cursor_y, "Error: PID inválido", 0x0C);
                }
            } else {
                // Buscar por nombre
                uint8_t found = 0;
                for (uint8_t i = 0; i < process_count; i++) {
                    if (strcmp(processes[i].name, target) == 0) {
                        if (processes[i].status == PROCESS_STOPPED) {
                            processes[i].status = PROCESS_RUNNING;
                            active_processes++;
                            print(CONSOLE_START_X, cursor_y, "Proceso reanudado: ", CONSOLE_TEXT_COLOR);
                            print(CONSOLE_START_X + 19, cursor_y, processes[i].name, 0x0A);
                        } else {
                            print(CONSOLE_START_X, cursor_y, "El proceso ya está activo: ", CONSOLE_TEXT_COLOR);
                            print(CONSOLE_START_X + 27, cursor_y, processes[i].name, 0x0C);
                        }
                        found = 1;
                        break;
                    }
                }

                if (!found) {
                    print(CONSOLE_START_X, cursor_y, "Error: Proceso no encontrado: ", CONSOLE_TEXT_COLOR);
                    print(CONSOLE_START_X + 31, cursor_y, target, 0x0C);
                }
            }
            cursor_y++;
            return 1;
        }

        // Opción de proceso desconocida
        print(CONSOLE_START_X, cursor_y, "Uso: process -l|-k|-r [pid|nombre]", 0x0C);
        cursor_y++;
        return 1;
    }

    // Comando no reconocido
    print(CONSOLE_START_X, cursor_y, "Comando desconocido: ", 0x0C);
    print(CONSOLE_START_X + 20, cursor_y, cmd->args[0], 0x0C);
    cursor_y++;
    print(CONSOLE_START_X, cursor_y, "Escribe 'help' para ver los comandos disponibles.", 0x07);
    cursor_y++;

    return 0;
}

// Procesar entrada de teclado
void process_key(uint8_t scancode) {
    // Definimos c aquí para evitar problemas de ámbito
    char c = 0;

    // Verificar el estado actual del proceso Portal
    static int portal_running = 0;
    static int portal_process_id = -1;

    // Actualizar estado de Portal primero
    int found_portal = 0;
    for (uint8_t i = 0; i < process_count; i++) {
        if (strcmp(processes[i].name, "Portal") == 0) {
            portal_process_id = i;
            portal_running = (processes[i].status == PROCESS_RUNNING);
            found_portal = 1;
            break;
        }
    }

    // Si no se encuentra proceso Portal, desactivar
    if (!found_portal) {
        portal_process_id = -1;
        portal_running = 0;
    }

    // Solo procesamos las teclas presionadas (no liberadas)
    if (scancode & 0x80) return;

    // Diagnóstico: Mostrar scancode en hexadecimal (puede eliminarse o comentarse)
    // char sc_hex[3];
    // sc_hex[0] = "0123456789ABCDEF"[(scancode >> 4) & 0xF];
    // sc_hex[1] = "0123456789ABCDEF"[scancode & 0xF];
    // sc_hex[2] = '\0';
    // print(70, 5, sc_hex, 0x0F);

    switch (scancode) {
        case ENTER:
            // Procesar el comando
            input_buffer[buffer_position] = '\0';

            // Limpiar línea actual y mostrar el comando completo
            print(CONSOLE_START_X, cursor_y, "                                                                                ", CONSOLE_TEXT_COLOR);
            print(CONSOLE_START_X, cursor_y, "> ", CONSOLE_PROMPT_COLOR);
            print(CONSOLE_START_X + 2, cursor_y, input_buffer, CONSOLE_TEXT_COLOR);

            // Crear una nueva línea para la salida
            cursor_y++;
            if (cursor_y >= CONSOLE_END_Y) {
                // Si llegamos al final del área de consola, desplazamos todo el contenido
                cursor_y = CONSOLE_START_Y + 1;
                clear_region(CONSOLE_START_Y + 1, CONSOLE_END_Y, CONSOLE_TEXT_COLOR);
            }

            // Si Portal está activo, enviamos comandos allí
            if (portal_running) {
                // Enviar el comando a Portal si no está vacío
                if (buffer_position > 0) {
                    // Verificar si el comando es "exit" para manejar adecuadamente
                    if (strcmp(input_buffer, "exit") == 0) {
                        portal_running = 0; // Desactivar Portal localmente
                        portal_process_id = -1;
                        portal_command_ready = -1;  // Señal para cerrar el proceso Portal
                    } else {
                        // Para otros comandos, solo los enviamos normalmente
                        send_to_portal(input_buffer);
                    }
                }
            } else {
                // En modo consola básica
                if (buffer_position > 0) {
                    // Verificar si el comando es "portal" para iniciar la shell
                    if (strcmp(input_buffer, "portal") == 0) {
                        // Buscar si ya existe un proceso Portal detenido
                        int existing_portal = -1;
                        int portal_already_active = 0;

                        for (uint8_t i = 0; i < process_count; i++) {
                            if (strcmp(processes[i].name, "Portal") == 0) {
                                existing_portal = i;
                                portal_already_active = (processes[i].status == PROCESS_RUNNING);
                                break;
                            }
                        }

                        // Si existe, reactivarlo; si no, crear uno nuevo
                        if (existing_portal >= 0) {
                            if (!portal_already_active) {
                                processes[existing_portal].status = PROCESS_RUNNING;
                                active_processes++;
                                portal_process_id = existing_portal;
                                portal_running = 1;
                                print(CONSOLE_START_X, cursor_y, "Reactivando Portal Shell...", 0x0A);
                                // Actualizar UI a modo Portal
                                print(CONSOLE_START_X, CONSOLE_START_Y, "Shell Portal v" PORTAL_VERSION " - escriba 'help' para obtener ayuda", CONSOLE_PROMPT_COLOR);
                                print(0, CONSOLE_STATUS_LINE, "                                                                                ", 0x00);
                            } else {
                                print(CONSOLE_START_X, cursor_y, "Portal Shell ya está activo", 0x0E);
                            }
                        } else {
                            // Iniciar Portal como un proceso independiente
                            portal_process_id = create_process("Portal", process_portal);
                            portal_running = 1;
                            print(CONSOLE_START_X, cursor_y, "Iniciando Portal Shell...", 0x0A);
                            // Eliminar el mensaje de estado para dar más espacio a la shell Portal
                            print(0, CONSOLE_STATUS_LINE, "                                                                                ", 0x00);
                        }
                        cursor_y++;
                    } else {
                        // En modo consola simple, solo imprimimos el texto ingresado
                        print(CONSOLE_START_X, cursor_y, "Ingresaste: ", 0x07);
                        print(CONSOLE_START_X + 12, cursor_y, input_buffer, 0x0E);
                        cursor_y++;
                    }
                }
            }

            // Crear una nueva línea para el siguiente prompt
            if (cursor_y >= CONSOLE_END_Y) {
                cursor_y = CONSOLE_START_Y + 1;
                clear_region(CONSOLE_START_Y + 1, CONSOLE_END_Y, CONSOLE_TEXT_COLOR);
            }

            // Nuevo prompt
            print(CONSOLE_START_X, cursor_y, "> ", CONSOLE_PROMPT_COLOR);
            buffer_position = 0;
            input_buffer[0] = '\0';
            set_cursor(CONSOLE_START_X + 2, cursor_y);
            break;

        case BACKSPACE:
        case 0x08: // Añadimos un scancode alternativo para el BACKSPACE que se usa en algunos teclados
            if (buffer_position > 0) {
                buffer_position--;
                input_buffer[buffer_position] = '\0';

                // Redibuja toda la línea para mostrar el cambio
                update_console_line();
            }
            break;

        default:
            // Usar nuestra función mejorada de mapeo de scancodes
            c = scancode_to_ascii(scancode);

            // Solo si tenemos un carácter válido y no superamos el límite
            if (c != 0 && buffer_position < MAX_COMMAND_LENGTH) {
                input_buffer[buffer_position] = c;
                buffer_position++;
                input_buffer[buffer_position] = '\0';

                // Redibuja toda la línea con el nuevo carácter
                update_console_line();
            }
            break;
    }
}

// Actualiza el tick count del PIT
void pit_tick(void) {
    pit_ticks++;
}
