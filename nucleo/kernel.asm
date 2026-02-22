// nucleo/kernel.asm
.global _inicio
.global _svc_retorno_el1

.section .bss
.align 4
_pilha_el0:
    .space 4096 // 4KB pra EL0
_pilha_el0_fim:

.section .text.kernel
_inicio:
    mov x30, xzr
    // zerar a sessão BSS
    ldr x0, = _bss_inicio
    ldr x1, = _bss_fim 
    mov x2, 0 // valor pra zerar
zerar_bss:
    cmp x0, x1
    b.ge fim_zerar_bss
    str x2, [x0], 8 // zera 8 bytes e avança
    b zerar_bss
fim_zerar_bss:
    msr spsel, 1
    
    // configura pilha
    ldr x0, = _pilha_fim
    mov sp, x0
    
    // configura UART
    bl _config_uart
    
    // configura vetores de exceção
    bl _config_excecao

    // mensagem de confirmação
    ldr x0, = msg_kernel
    bl _escrever_tex
    
    // Configura a pilha de EL0 (SP_EL0)
    // Usa uma região separada da pilha do kernel
    ldr x0, =_pilha_el0_fim
    msr sp_el0, x0

    // ELR_EL1 = endereço onde EL0 vai começar
    ldr x0, =_testar_svc
    msr elr_el1, x0

    // SPSR_EL1 = EL0t, interrupções habilitadas
    // M[3:0]=0000 (EL0t), F=0, I=0, A=0, D=0
    mov x0, 0x0
    msr spsr_el1, x0

    eret  // salta para _testar_svc em EL0
    
    bl _iniciar_video
    
    bl ns_abrir

    // loop infinito
1: 
    wfe
    b 1b
_svc_retorno_el1: //ponto de retorno depois do EL0
    bl _iniciar_video
    bl ns_abrir
.section .rodata
msg_kernel: .asciz "[Kernel]: Executando, Sistema carregado com sucesso\r\n"
