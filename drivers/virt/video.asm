// drivers/virt/video.asm
.global _iniciar_video
.global _escrever_pixel
.global _limpar_tela
.global _desenhar_retangulo

// constantes VirtIO
MAGICO = 0x00
VERSAO = 0x04
AMBIENTE_ID = 0x08
VENDOR_ID = 0x0C
STATUS = 0x70
// constantes especificas
VIRTIO_GPU_ID = 16 // ID 16 = GPU
QUADROBUFFER_SEGURO = 0x44000000 // 64MB acima do inicio da RAM

.section .bss
.align 8
fb_base: .quad 0 // endereço onde vai escrever os pixels
fb_vertical: .word 0
fb_horizontal: .word 0
fb_tom: .word 0
gpu_mmio_base: .quad 0 // endereço de controle da GPU(mmio)

.section .text
_iniciar_video:
    stp x29, x30, [sp, -16]!
    mov x29, sp
    stp x19, x20, [sp, -16]!

    ldr x0, = msg_buscando_gpu
    bl _escrever_tex

    // 1. tenta encontrar a GPU no barramento
    bl _encontrar_gpu_mmio
    
    // se x0 for 0, falhou
    cbz x0, erro_gpu_nao_encontrada

    // 2. salva o endereço base da GPU
    mov x19, x0
    ldr x1, = gpu_mmio_base
    str x0, [x1]

    ldr x0, = msg_gpu_encontrada
    bl _escrever_tex
    
    // imprime o endereço onde achou
    mov x0, x19
    bl _escrever_hex
    ldr x0, = nova_linha
    bl _escrever_tex

    // 3. inicia o status do VirtIO(protocolo basico)
    // reinicia(0)
    mov w1, 0
    str w1, [x19, STATUS]
    
    // acknowledge(1)
    mov w1, 1
    str w1, [x19, STATUS]
    
    // driver(1 | 2 = 3)
    mov w1, 3
    str w1, [x19, STATUS]

    // 4. configuração(não configura de verdade ainda)
    // define uma area de RAM segura pra desenhar, mesmo que não apareça
    ldr x0, = QUADROBUFFER_SEGURO 
    ldr x1, = fb_base
    str x0, [x1]
    // define resolução padrão(apenas pra logica de desenho)
    mov w0, 1024
    ldr x1, = fb_vertical
    str w0, [x1]

    mov w0, 768
    ldr x1, = fb_horizontal
    str w0, [x1]

    mov w0, 4096 // 1024 * 4 bytes
    ldr x1, = fb_tom
    str w0, [x1]

    ldr x0, = msg_fb_configurado
    bl _escrever_tex

    // limpa a tela, vau escrever em 0x44000000
    // cor azul escuro
    ldr w0, = 0xFF000080
    // bl _limpar_tela

    b fim_inicio
erro_gpu_nao_encontrada:
    ldr x0, = msg_erro_gpu
    bl _escrever_tex
fim_inicio:
    ldp x19, x20, [sp], 16
    ldp x29, x30, [sp], 16
    ret
// varre a memoria mmio procurando ID ambiente 16
// x0 = retorna endereço Base ou 0
_encontrar_gpu_mmio:
    stp x29, x30, [sp, -16]!
    mov x29, sp
    stp x19, x20, [sp, -16]!

    ldr x19, = 0x0a000000  // inicio mmio virt
    mov x20, 0 // contador(0 a 31)
loop_busca:
    cmp x20, 32
    b.ge nao_achei

    // verifica o valor magico(0x74726976)
    ldr w1, [x19, MAGICO]
    ldr w2, = 0x74726976
    cmp w1, w2
    b.ne proximo_slot

    // verifica ID ambiente(GPU = 16)
    ldr w1, [x19, AMBIENTE_ID]
    cmp w1, VIRTIO_GPU_ID
    b.eq achei
proximo_slot:
    add x19, x19, 0x200 // avança 512 bytes
    add x20, x20, 1
    b loop_busca
achei:
    mov x0, x19 // retorna endereço encontrado
    b fim_busca
nao_achei:
    mov x0, 0
fim_busca:
    ldp x19, x20, [sp], 16
    ldp x29, x30, [sp], 16
    ret
// _escrever_pixel
// w0=x, w1=y, w2=cor(ARGB)
_escrever_pixel:
    // verifica se fb_base foi iniciado
    ldr x3, = fb_base
    ldr x3, [x3]
    cbz x3, ret_pixel // se for 0, retorna(proteção)

    ldr x4, = fb_tom
    ldr w4, [x4]
    
    // calculo: endereço = base + (y * tom) + (x * 4)
    mul w5, w1, w4 // y * tom
    mov w6, 4
    madd w5, w0, w6, w5 // + (x * 4)
    add x3, x3, x5 // endereço final

    str w2, [x3] // escreve o pixel na RAM
ret_pixel:
    ret
// _limpar_tela
// w0 = cor(0x00RRGGBB)
_limpar_tela:
    stp x29, x30, [sp, -32]!
    mov x29, sp
    str x19, [sp, 16]

    mov w19, w0
    
    ldr x0, = fb_base
    ldr x0, [x0]
    cbz x0, fim_limpar // proteção se base for 0

    ldr x1, = fb_horizontal
    ldr w1, [x1]
    ldr x2, =fb_tom
    ldr w2, [x2]

    mul w3, w1, w2 // total bytes
    mov x4, 0
loop_limpar:
    cmp x4, x3
    b.ge fim_limpar
    str w19, [x0, x4]
    add x4, x4, 4
    b loop_limpar
fim_limpar:
    ldr x19, [sp, 16]
    ldp x29, x30, [sp], 32
    ret
// _desenhar_retangulo
// w0=x, w1=y, w2=v, w3=h, w4=cor
_desenhar_retangulo:
    stp x29, x30, [sp, -48]!
    mov x29, sp
    stp x19, x20, [sp, 16]
    stp x21, x22, [sp, 32]
    str x23, [sp, 48]

    mov w19, w0 // x
    mov w20, w1 // y
    mov w21, w2 // v
    mov w22, w3 // h
    mov w23, w4 // cor

    mov w24, 0 // contador y
loop_quadrado_y:
    cmp w24, w22
    b.ge fim_quadrado

    mov w25, 0 // contador x
loop_quadrado_x:
    cmp w25, w21
    b.ge prox_linha_quadrado

    // calcula coordenadas atuais
    add w0, w19, w25
    add w1, w20, w24
    mov w2, w23
    bl _escrever_pixel

    add w25, w25, 1
    b loop_quadrado_x
prox_linha_quadrado:
    add w24, w24, 1
    b loop_quadrado_y
fim_quadrado:
    ldr x23, [sp, 48]
    ldp x21, x22, [sp, 32]
    ldp x19, x20, [sp, 16]
    ldp x29, x30, [sp], 48
    ret
.section .rodata
msg_buscando_gpu: .asciz "[Video]: Procurando VirtIO GPU...\n"
msg_gpu_encontrada: .asciz "[Video]: GPU Encontrada em: "
msg_erro_gpu: .asciz "[Video]: ERRO - GPU Nao encontrada!\n"
nova_linha: .asciz "\n"
msg_fb_configurado: .asciz "[Video]: Quadrobuffer seguro configurado na RAM\n"
