// testes/teste_svc.asm
.global _testar_svc

.section .text
_testar_svc:
    // TESTE 1: escrever 1
    mov x8, 64 // escrever
    mov x0, 1 // saida
    ldr x1, = msg_escrever // buffer
    mov x2, 42  // tamanho
    svc 0
    // x0 = bytes escritos(positivo = ok)

    // TESTE 2: escrever 9(invalido -> -9)
    mov x8, 64
    mov x0, 9 // saida invalido
    ldr x1, = msg_escrever
    mov x2, 42
    svc 0
    // x0 deve ser -9, sem saida na UART

    // TESTE 3: chamada inexistente -> -38
    mov x8, 999
    svc 0
    // x0 deve ser -38; imprime msg_sistema_naoimpl na UART

    // ENCERRA: svc 93(saida)
    mov x8, 93
    mov x0, 0
    svc 0

.section .rodata
msg_teste_descendo:
    .asciz "[TesteSVC]: Descendo pra EL0, DAIF mascarado...\r\n"
msg_escrever:
    .asciz "[TesteSVC EL0]: svc escrever 1 funcionou\r\n"
