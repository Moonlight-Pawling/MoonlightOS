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
#define CONSOLE_STATUS_LINE 23          // Línea de estado (movida una línea más abajo)
#define CONSOLE_FOOTER_LINE 24          // Línea de pie de página con heartbeat
#define CONSOLE_START_X 0
#define CONSOLE_START_Y 12              // Iniciamos la consola más arriba para evitar solapamiento
#define CONSOLE_END_Y 20                // Última línea de la consola (reducida para dejar espacio de seguridad)
#define CONSOLE_PROMPT_COLOR 0x0B
#define CONSOLE_TEXT_COLOR 0x07
#define MAX_COMMAND_LENGTH 78           // Dejamos espacio para el prompt "> "
#define BACKSPACE 0x0E
#define ENTER 0x1C

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

    // Mostrar el prompt
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

    // Título del intérprete de comandos "Portal"
    print(CONSOLE_START_X, CONSOLE_START_Y, "Portal v1.0 - Shell de MoonlightOS", CONSOLE_PROMPT_COLOR);

    // Inicializamos el cursor debajo del título
    cursor_y = CONSOLE_START_Y + 1;
    print(CONSOLE_START_X, cursor_y, "> ", CONSOLE_PROMPT_COLOR);  // Cambiamos "$ " por "> " como nuevo prompt
    buffer_position = 0;
    input_buffer[0] = '\0';
    set_cursor(CONSOLE_START_X + 2, cursor_y);
}

// Convertir scancode a ASCII considerando el teclado en español/latino
char scancode_to_ascii(uint8_t scancode) {
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

// Definiciones para Portal Shell
#define PORTAL_VERSION "1.0"
#define PORTAL_MAX_ARGS 16
#define PORTAL_PROMPT "> "

// Estructura para almacenar un comando procesado
typedef struct {
    char command[MAX_COMMAND_LENGTH + 1];
    char *args[PORTAL_MAX_ARGS];
    int argc;
} PortalCommand;

// Forward declarations para la shell Portal
void portal_init(void);
void portal_print_prompt(void);
void portal_parse_command(char* input, PortalCommand* cmd);
int portal_execute_command(PortalCommand* cmd);
void portal_display_welcome(void);

// Constantes para comandos de Portal Shell
#define CMD_UNKNOWN    0
#define CMD_PROCESS    1
#define CMD_HELP       2
#define CMD_CLEAR      3
#define CMD_EXIT       4
#define CMD_VERSION    5
#define CMD_ABOUT      6

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
            if (arg_start && strcmp(arg_start, "-l") == 0) {
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
            } else {
                print(CONSOLE_START_X, cursor_y, "Uso: process -l (listar procesos)", 0x0C);
                cursor_y++;
            }
            break;

        case CMD_HELP:
            print(CONSOLE_START_X, cursor_y, "Comandos disponibles:", CONSOLE_PROMPT_COLOR);
            cursor_y++;
            print(CONSOLE_START_X + 2, cursor_y, "process -l  : Listar procesos activos", CONSOLE_TEXT_COLOR);
            cursor_y++;
            print(CONSOLE_START_X + 2, cursor_y, "clear       : Limpiar pantalla", CONSOLE_TEXT_COLOR);
            cursor_y++;
            print(CONSOLE_START_X + 2, cursor_y, "help        : Mostrar esta ayuda", CONSOLE_TEXT_COLOR);
            cursor_y++;
            break;

        case CMD_CLEAR:
            clear_region(CONSOLE_START_Y + 1, CONSOLE_END_Y, CONSOLE_TEXT_COLOR);
            cursor_y = CONSOLE_START_Y + 1;
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

    // Mostrar en pantalla
    print(26, CONSOLE_FOOTER_LINE, h_str, 0x0E);
    putchar(28, CONSOLE_FOOTER_LINE, ':', 0x07);
    print(29, CONSOLE_FOOTER_LINE, m_str, 0x0E);
    putchar(31, CONSOLE_FOOTER_LINE, ':', 0x07);
    print(32, CONSOLE_FOOTER_LINE, s_str, 0x0E);
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

// Proceso de consola
void process_console(uint64_t ticks) {
    static int last_key_check = 0;

    // Verificar si hay una tecla presionada cada cierto número de ticks
    if (ticks - last_key_check >= 2) { // Reducir la frecuencia de verificación
        last_key_check = ticks;

        if (inb(0x64) & 1) {
            uint8_t scancode = inb(0x60);
            process_key(scancode);
        }
    }
}

// Procesar entrada de teclado
void process_key(uint8_t scancode) {
    // Solo procesamos las teclas presionadas (no liberadas)
    if (scancode & 0x80) return;

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
                // Por ahora simplemente volvemos a la primera línea después del título
                cursor_y = CONSOLE_START_Y + 1;
                clear_region(CONSOLE_START_Y + 1, CONSOLE_END_Y, CONSOLE_TEXT_COLOR);
            }

            // Procesar el comando ingresado si no está vacío
            if (buffer_position > 0) {
                process_command(input_buffer);
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
            if (buffer_position > 0) {
                buffer_position--;
                input_buffer[buffer_position] = '\0';

                // Redibuja toda la línea para mostrar el cambio
                update_console_line();
            }
            break;

        default:
            // Usar nuestra función mejorada de mapeo de scancodes
            char c = scancode_to_ascii(scancode);

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
void pit_tick() {
    pit_ticks++;
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

    // Crear procesos iniciales - La consola es ahora el proceso 1 (PID 0)
    create_process("Console", process_console);
    create_process("Heartbeat", process_heartbeat);
    create_process("Counter", process_counter);

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

    // Inicializar la consola
    init_console();

    // Status bar
    print(0, CONSOLE_STATUS_LINE, "Estado: Consola basica activa - Listo para recibir comandos", 0x0A);
    print(0, CONSOLE_STATUS_LINE + 1, "-------------------------------------------------------------------------------", 0x07);

    // Footer con timestamp y heartbeat
    print(0, CONSOLE_FOOTER_LINE, "Tiempo: ", 0x07);

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
    // Limpiamos el área de consola primero
    clear_region(CONSOLE_START_Y, CONSOLE_END_Y, CONSOLE_TEXT_COLOR);

    // Título del intérprete de comandos "Portal"
    print(CONSOLE_START_X, CONSOLE_START_Y, "Portal v" PORTAL_VERSION " - Shell de MoonlightOS", CONSOLE_PROMPT_COLOR);

    // Mostrar información de bienvenida
    portal_display_welcome();

    // Inicializamos el cursor debajo del título
    cursor_y = CONSOLE_START_Y + 2; // Una línea más abajo después de la bienvenida
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

    // Extraer el nombre del comando (primera palabra)
    char* token = input;
    char* space = input;

    // Buscar el primer espacio
    while (*space && *space != ' ') space++;

    // Si hay espacio, lo reemplazamos con nulo temporalmente
    int has_args = 0;
    if (*space == ' ') {
        *space = '\0';
        has_args = 1;
    }

    // El primer token es el nombre del comando
    cmd->args[0] = token;
    cmd->argc = 1;

    // Si no hay argumentos, terminamos
    if (!has_args) return;

    // Restaurar el espacio
    *space = ' ';

    // Procesar los argumentos
    token = space + 1;

    // Saltear espacios iniciales en los argumentos
    while (*token == ' ') token++;

    // Si no quedan argumentos después de los espacios, terminamos
    if (*token == '\0') return;

    // Extraer argumentos
    int arg_index = 1; // Empezamos en 1 porque el 0 es el comando
    char* arg_start = token;

    while (*token && arg_index < PORTAL_MAX_ARGS) {
        // Si encontramos un espacio, marcamos el final del argumento
        if (*token == ' ') {
            *token = '\0';
            cmd->args[arg_index++] = arg_start;

            // Buscar el siguiente argumento
            token++;
            while (*token == ' ') token++;

            // Si no hay más texto, terminamos
            if (*token == '\0') break;

            // Nuevo inicio de argumento
            arg_start = token;
        } else {
            token++;
        }
    }

    // Añadir el último argumento si queda alguno
    if (*arg_start && arg_index < PORTAL_MAX_ARGS) {
        cmd->args[arg_index++] = arg_start;
    }

    // Actualizar el contador de argumentos
    cmd->argc = arg_index;
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
        print(CONSOLE_START_X, cursor_y, "Comandos de Portal Shell:", CONSOLE_PROMPT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X + 2, cursor_y, "process -l  : Listar procesos activos", CONSOLE_TEXT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X + 2, cursor_y, "clear       : Limpiar pantalla", CONSOLE_TEXT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X + 2, cursor_y, "help        : Mostrar esta ayuda", CONSOLE_TEXT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X + 2, cursor_y, "version     : Mostrar versión de Portal", CONSOLE_TEXT_COLOR);
        cursor_y++;
        print(CONSOLE_START_X + 2, cursor_y, "about       : Información sobre Portal Shell", CONSOLE_TEXT_COLOR);
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

    if (strcmp(cmd->args[0], "process") == 0) {
        // Verificar si se especificó el argumento -l
        if (cmd->argc > 1 && strcmp(cmd->args[1], "-l") == 0) {
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
        } else {
            print(CONSOLE_START_X, cursor_y, "Uso: process -l (listar procesos)", 0x0C);
            cursor_y++;
        }
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
