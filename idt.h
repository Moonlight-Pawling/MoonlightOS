#ifndef IDT_H
#define IDT_H

#include <stdint.h>

// Estructura de una entrada IDT
struct idt_entry {
    uint16_t offset_low;    // Offset bits 0-15
    uint16_t selector;      // Selector de código
    uint8_t  zero;          // Siempre 0
    uint8_t  type_attr;     // Tipo y atributos
    uint16_t offset_high;   // Offset bits 16-31
} __attribute__((packed));

// Puntero IDT
struct idt_ptr {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed));

// Funciones
void idt_init();
void idt_set_gate(uint8_t num, uint32_t offset, uint16_t selector, uint8_t flags);

#endif