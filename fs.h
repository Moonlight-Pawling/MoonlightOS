#ifndef FS_H
#define FS_H

// Definiciones del sistema de archivos simple
#define FS_MAX_FILES 32
#define FS_MAX_DIRS 16
#define FS_MAX_NAME_LEN 32
#define FS_MAX_PATH_LEN 128
#define FS_MAX_CONTENT_SIZE 4096

// Tipos de nodos de sistema de archivos
#define FS_TYPE_FILE 1
#define FS_TYPE_DIR 2

// Estructura de un archivo
typedef struct {
    char name[FS_MAX_NAME_LEN];
    uint8_t type;
    char content[FS_MAX_CONTENT_SIZE];
    uint32_t size;
    uint8_t parent_dir;
} FileNode;

// Estructura de un directorio
typedef struct {
    char name[FS_MAX_NAME_LEN];
    uint8_t type;
    uint8_t parent_dir;
    uint8_t num_children;
    uint8_t children[FS_MAX_FILES]; // Índices a archivos o directorios hijos
} DirNode;

// Inicializar el sistema de archivos
void fs_init(void);

// Crear un archivo
int fs_create_file(const char* name, const char* content);

// Crear un directorio
int fs_create_dir(const char* name);

// Leer un archivo
const char* fs_read_file(const char* name);

// Cambiar el directorio actual
int fs_change_dir(const char* path);

// Listar el contenido del directorio actual
void fs_list_dir(void);

// Obtener la ruta actual
const char* fs_get_current_path(void);

// Funciones de utilidades para el sistema de archivos
int fs_path_exists(const char* path);
uint8_t fs_find_file_by_name(const char* name);
uint8_t fs_find_dir_by_name(const char* name);
uint8_t fs_find_node_by_path(const char* path, uint8_t* is_dir);

#endif // FS_H
got