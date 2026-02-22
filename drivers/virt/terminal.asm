// drivers/virt/terminal.asm
.global _escrever_saida
.global _escrever_tex
.global _escrever_car
.global _escrever_hex
.global _escrever_decimal
.global _escrever_hex64
.global _escrever_int
.global _escrever_longo
.global _escrever_flu
.global _escrever_bool
.global _obter_car
.global _config_uart

.section .bss
uart_base_real: .quad 0
.align 4
hex_buffer: .space 17
    .byte 0
.align 8
dec_buffer: .space 21

.section .text
_config_uart:
    // inicia uart_base_real so uma vez
    ldr x9, = UART_BASE
    ldr x10, = uart_base_real
    str x9, [x10]
    
    // habilita TX
    mov w1, 0x301
    ldr x2, = UART_CR
    str w1, [x9, x2]
    ret
_escrever_car:
    // pega UART base diretamente
    ldr x9, = uart_base_real
    ldr x9, [x9]
    // escreve direto
    ldr x3, = UART_DR
    strb w0, [x9, x3]
    ret
_obter_car:
    ldr x9, = uart_base_real
    ldr x9, [x9]
1:
    ldr x3, = UART_FR
    ldr w1, [x9, x3]
    ldr x2, = FR_RXFE
    ands w1, w1, w2
    b.ne 1b
    ldr x3, = UART_DR
    ldrb w0, [x9, x3]
    ret
_escrever_tex:
    stp x0, x1, [sp, -16]!
    stp x2, x4, [sp, -16]!
    
    ldr x1, = UART_BASE
1:
    ldrb w2, [x0], 1
    cbz w2, 2f
    ldr x4, = UART_DR
    strb w2, [x1, x4]
    b 1b
2:
    ldp x2, x4, [sp], 16
    ldp x0, x1, [sp], 16
    ret
_escrever_saida:
    // x0 = buffer, x1 = conta
    stp x2, x3, [sp, -16]! // preserva x2, x3
    stp x4, x5, [sp, -16]! // preserva x4, x5
    
    mov x2, x0 // buffer pra x2
    mov x3, x1 // conta pra x3
    
    ldr x4, = UART_BASE
    ldr x5, = UART_DR
1:
    cbz x3, 2f // Se conta == 0, termina
    ldrb w0, [x2], 1 // carrega caractere em w0
    strb w0, [x4, x5] // escreve caractere na uart
    sub x3, x3, 1 // decrementa conta
    b 1b
2:
    ldp x4, x5, [sp], 16
    ldp x2, x3, [sp], 16
    mov x0, x1 // retorna conta original
    ret
_escrever_hex:
    // x0 = valor pra escrever
    stp x29, x30, [sp, -48]!
    mov x29, sp
    stp x19, x20, [sp, 16]
    str x21, [sp, 32]

    mov x19, x0
    mov w20, 16
    ldr x21, = hex_buffer
1:
    sub w20, w20, 1
    and w0, w19, 0xf
    cmp w0, 9
    b.gt 2f
    add w0, w0, '0'
    b 3f
2:
    add w0, w0, 'a' - 10
3:
    strb w0, [x21, x20]
    lsr x19, x19, 4
    cbnz w20, 1b

    ldr x0, = hex_buffer
    bl _escrever_tex

    ldr x21, [sp, 32]
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 48
    ret
_escrever_decimal:
    // x0 = valor pra escrever
    stp x29, x30, [sp, -48]!
    mov x29, sp
    stp x19, x20, [sp, 16]
    str x21, [sp, 32]

    mov x19, x0
    ldr x21, = dec_buffer
    add x21, x21, 20
    mov w0, 0
    strb w0, [x21], -1

    mov x20, 10
1:
    udiv x0, x19, x20
    msub x1, x0, x20, x19
    add w1, w1, '0'
    strb w1, [x21], -1
    mov x19, x0
    cbnz x19, 1b

    add x0, x21, 1
    bl _escrever_tex

    ldr x21, [sp, 32]
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 48
    ret
    
// escreve um número hexadecimal 64 bits
// x0 = valor a imprimir
// usa _escrever_tex para cada byte
.align 3
_escrever_hex64:
    stp x29, x30, [sp, -48]!
    mov x29, sp
    str x19, [sp, 16]
    str x20, [sp, 24]
    str x21, [sp, 32]

    mov x19, x0 // valor
    mov x20, 60 // shift inicial(bits 63..0, de 4 em 4)
    adr x21, _hex_cars

    ldr x0, = _hex_Ox
    bl  _escrever_tex

_hex_loop:
    lsr  x1, x19, x20 // desloca pra pegar mordidela atual
    and  x1, x1, 0xF // isola o mordidela
    ldrb w0, [x21, x1] // busca o caractere hex
    // imprime o caractere via UART diretamente
    bl _escrever_car
    subs x20, x20, 4
    b.ge _hex_loop

    mov x0, '\n'
    bl  _escrever_tex

    ldr x19, [sp, 16]
    ldr x20, [sp, 24]
    ldr x21, [sp, 32]
    ldp x29, x30, [sp], 48
    ret
// fn: [_escrever_int]
.align 2
_escrever_int:
    mov w1, w0 // w1 = numero
    ldr x0, = 5f // x0 = buffer
    mov x19, 0 // x19 = contador de caracteres
    
    cmp w1, 0
    b.ge 1f
    neg w1, w1 // torna positivo
    mov w2, '-'
    strb w2, [x0], 1 // escreve sinal
    mov x19, 1 // contador = 1
1:
    // escreve dígitos em ordem reversa
    mov x2, x0 // x2: aponta pra posição atual
2:
    mov w3, 10
    udiv w4, w1, w3 // w4 = quociente
    msub w5, w4, w3, w1 // w5 = resto
    add w5, w5, '0' // caractere
    strb w5, [x2], 1 // armazena
    add x19, x19, 1 // incrementa contador
    mov w1, w4
    cbnz w1, 2b
    // inverte a string de dígitos(a parte após o sinal, se existir)
    // x0: aponta pro início dos dígitos(pode ser buffer_int ou buffer_int+1)
    // x2-1: é o último dígito
    sub x2, x2, 1 // x2 aponta para o último dígito
    mov x3, x0 // x3 aponta para o primeiro dígito
3:
    cmp x3, x2
    b.ge 4f
    ldrb w4, [x3]
    ldrb w5, [x2]
    strb w5, [x3], 1
    strb w4, [x2], -1
    b 3b
4:
    ldr x0, = 5f
    mov x1, x19 // x19: o número de caracteres
    bl _escrever_saida
    ret
.section .data
5: // buffer do inteiro
    .fill   32, 1, 0
// fim: [_escrever_int]
// fn: [_escrever_flu] (vars: 176, total: 320)
.align 2
_escrever_flu:
  // prologo
  stp x29, x30, [sp, -48]!
  mov x29, sp
  str d0, [sp, 16] // param valor
  
  // converte pra centavos/inteiro diretamente
  adr x0, 1f
  ldr s0, [x0]
  ldr s1, [sp, 16]
  fmul s0, s1, s0
  fcvtzs w8, s0 // w8 = valor * 100 como inteiro
  
  // inicia indice do buffer
  mov w9, 0 // w9 = indice no buffer
  add x10, sp, 24 // x10 = buffer(48-24=24 bytes disponiveis)
  // verifica se é negativo
  cmp w8, 0
  b.ge .positivo
  mov w0, '-'
  strb w0, [x10], 1 // armazena '-' e incrementar ponteiro
  add w9, w9, 1
  neg w8, w8 // tornar positivo
.positivo:
  // separa parte inteira e decimal
  mov w0, 100
  sdiv w11, w8, w0 // w11 = parte inteira
  msub w12, w11, w0, w8 // w12 = parte decimal(0-99)
  
  // escreve parte inteira
  cmp w11, 0
  b.ne .tem_inteiro
  
  // caso especial: inteiro é zero
  mov w0, '0'
  strb w0, [x10], 1
  add w9, w9, 1
  b .decimal
.tem_inteiro:
  // converte inteiro pra texto(reverso)
  add x13, sp, 40 // buffer temporario(8 bytes)
  mov x14, x13
.loop_inteiro:
  mov w0, 10
  sdiv w1, w11, w0
  msub w0, w1, w0, w11
  add w0, w0, '0'
  strb w0, [x14], 1
  mov w11, w1
  cmp w11, 0
  b.ne .loop_inteiro
  
  // copia na ordem correta
  sub x14, x14, 1
.loop_copiar:
  ldrb w0, [x14], -1
  strb w0, [x10], 1
  add w9, w9, 1
  cmp x14, x13
  b.ge .loop_copiar
.decimal:
  // ponto decimal
  mov w0, '.'
  strb w0, [x10], 1
  add w9, w9, 1
  
  // parte decimal(sempre 2 digitos)
  mov w0, 10
  sdiv w1, w12, w0 // dezenas
  msub w2, w1, w0, w12 // unidades
  
  add w1, w1, '0'
  add w2, w2, '0'
  
  strb w1, [x10], 1
  strb w2, [x10], 1
  add w9, w9, 2
  
  // termina com '\0'
  mov w0, 0
  strb w0, [x10]
  
  // imprime:
  add x0, sp, 24
  mov w1, w9
  bl _escrever_saida
  
  // epilogo
  ldp x29, x30, [sp], 48
  ret
1:
    .float 100.0
// fim: [_escrever_flu]
// fn: [_escrever_longo]
.align 2
_escrever_longo:
    mov x1, x0 // x1 = numero(64 bits)
    ldr x0, =5f // x0 = buffer
    mov x19, 0 // x19 = contador de caracteres
    
    cmp x1, 0 // compara 64 bits
    b.ge 1f
    neg x1, x1 // torna positivo(64 bits)
    mov w2, '-'
    strb w2, [x0], 1 // escreve sinal(w2 é 32 bits)
    mov x19, 1 // contador = 1
1:
    // escreve digitos em ordem reversa
    mov x2, x0 // x2: aponta pra posição atual
2:
    mov x3, 10
    udiv x4, x1, x3 // x4 = quociente(64 bits)
    msub x5, x4, x3, x1 // x5 = resto(64 bits)
    add w5, w5, '0' // converte resto pra caractere (w5)
    strb w5, [x2], 1 // armazena o byte(w5)
    add x19, x19, 1 // incrementa contador
    mov x1, x4
    cbnz x1, 2b // continua se x1 != 0
    // inverte o texto de digitos
    sub x2, x2, 1 // x2 aponta para o ultimo digito
    mov x3, x0 // x3 aponta para o primeiro digito
3:
    cmp x3, x2
    b.ge 4f
    ldrb w4, [x3] // carrega byte(w4)
    ldrb w5, [x2] // carrega byte(w5)
    strb w5, [x3], 1 // armazena byte(w5)
    strb w4, [x2], -1 // armazena byte(w4)
    b 3b
4:
    ldr x0, = 5f
    mov x1, x19 // x19: o numero de caracteres
    bl _escrever_saida
    ret
.section .data
5: // buffer do inteiro
    .fill   32, 1, 0
// fim: [_escrever_longo]
// fn: [_escrever_bool]
.align 2
_escrever_bool:
    cmp w0, 0
    b.eq 1f
    adr x0, 3f
    mov x1, 7
    b 2f
1:
    adr x0, 4f
    mov x1, 5
2:
    bl _escrever_saida
    ret
// buffers do booleano
3:
    .asciz "verdade"
4:
    .asciz "falso"
// fim: [_escrever_bool]

.section .rodata
// tabela de caracteres hex
_hex_cars: .ascii "0123456789ABCDEF"
_hex_Ox: .asciz "0x"
