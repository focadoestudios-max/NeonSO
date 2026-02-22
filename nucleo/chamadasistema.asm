// nucleo/chamadasistema.asm
/*
* convenção:
* x8 = número da chamada de sistema
* x0–x5 = argumentos(arg0..arg5)
* x0 = valor de retorno
* svc 0 = disparo

* números implementados:
* 63 = ler
* 64 = escrever
* 93 = sair
* 94 = sair

* erros retornados como inteiros negativos:
* -9  = descritor invalido
* -38 = chamada não implementada
*/
.global _despachador_chamadasistema

/*
* entrada:  x8=número, x0-x5=argumentos
* saida: x0=resultado(negativo=erro)
*/
.section .text
.align 3
_despachador_chamadasistema:
    stp x29, x30, [sp, -16]!
    mov x29, sp

    cmp x8, 63
    b.eq _chamadasistema_ler

    cmp x8, 64
    b.eq _chamadasistema_escrever

    cmp x8, 93
    b.eq _chamadasistema_sair

    cmp x8, 94
    b.eq _chamadasistema_sair

    // chamada não implementada
    ldr x0, = msg_sistema_naoimpl
    bl _escrever_tex
    mov x0, -38
    b _despachador_saida

_despachador_saida:
    ldp x29, x30, [sp], 16
    ret

/* 64: escrever
* x0 = lugar onde escrever
* x1 = buf
* x2 = quantidade de bytes
* retorna: bytes escritos ou -EBADF
*/
.align 3
_chamadasistema_escrever:
    stp x29, x30, [sp, -16]!
    mov x29, sp

    // so suporta fd 1 e fd 2
    cmp x0, 1
    b.eq 1f
    cmp x0, 2
    b.eq 1f
    mov x0, -9 // -EBADF
    b 2f
1:
    // _escrever_saida(x0=buf, x1=conta) -> retorna conta em x0
    mov x0, x1 // buf
    mov x1, x2 // quantidade
    bl _escrever_saida
2:
    ldp x29, x30, [sp], 16
    b _despachador_saida

/* 63: ler
* x0 = fd(0 = UART)
* x1 = buf
* x2 = quantidade maxima
* retorna: bytes lidos ou -EBADF
*/
.align 3
_chamadasistema_ler:
    stp x29, x30, [sp, -64]!
    mov x29, sp
    stp x19, x20, [sp, 16]
    stp x21, x22, [sp, 32]

    // so suporta fd 0(entrada de texto)
    cmp x0, 0
    b.ne _ler_erro_fd

    mov x19, x1 // ponteiro pro buffer
    mov x20, x2 // contador maximo
    mov x21, 0 // bytes lidos até agora

_ler_loop:
    cbz x20, _ler_fim // atingiu limite -> para
    bl _obter_car // bloqueia até receber byte; retorna em w0
    strb w0, [x19], 1 // salva no buffer, avança ponteiro
    add x21, x21, 1
    sub x20, x20, 1
    cmp w0, '\n'
    b.eq _ler_fim // nova linha -> encerra leitura
    b _ler_loop

_ler_fim:
    mov x0, x21
    b _ler_saida

_ler_erro_fd:
    mov x0, -9 // -EBADF

_ler_saida:
    ldp x19, x20, [sp, 16]
    ldp x21, x22, [sp, 32]
    ldp x29, x30, [sp], 64
    b _despachador_saida

/* 93/94: sair
* x0 = codigo de saida
* retorna pro despachador(que faz eret de volta ao EL1)
* o kernel pode então continuar ou ir pro loop wfe
*/
_chamadasistema_sair:
    ldr x0, =msg_sistema_saindo
    bl _escrever_tex

    /*
    * modifica ELR_EL1 e SPSR_EL1 diretamente nos registradores
    * restaurar_contexto vai recarregar da pilha, então precisa
    * atualizar a pilha nas posições corretas(relativo ao frame do salvar_contexto)
    * SP aqui = base_frame - 16(pelo frame do despachador)
    * ELR ta em base_frame+248, logo sp+248+16 = sp+264 <- mas isso é ESR
    */
    // volta pro frame do salvar_contexto subindo 16
    add x1, sp, 16 // x1 aponta pro inicio do frame do salvar_contexto

    ldr x0, = _svc_retorno_el1
    str x0, [x1, 248] // escreve ELR_EL1 na posição correta

    mov x0, 0x3C5
    str x0, [x1, 256] // escreve SPSR_EL1 na posição correta

    mov x0, 0
    b _despachador_saida

// DADOS
.section .rodata
msg_sistema_saindo:
    .asciz "[Sistema]: Processo encerrado via chamada de sistema\r\n"
msg_sistema_naoimpl:
    .asciz "[Sistema]: Chamada de sistema não implementada\r\n"
    