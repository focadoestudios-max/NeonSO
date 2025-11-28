// biblis/ns.asm
.global ns_abrir

.section .text
ns_abrir:
    ldr x0, = msg_abrindo
    bl _escrever_tex
    ldr x0, = comando
    bl _escrever_tex
    b ns_loop
ns_loop:
    bl _obter_car
    
    cmp w0, 0x0D
    b.eq nova_linha
    
    bl _escrever_car
    
    cmp w0, 'a'
    b.eq 1f // ajuda
    
    cmp w0, 's'
    b.eq 2f // status
    
    b ns_loop
nova_linha:
    mov w0, 0x0A
    bl _escrever_car
    ldr x0, = comando
    bl _escrever_tex
    b ns_loop
1:
    mov w0, 0x0A
    bl _escrever_car
    ldr x0, = msg_ajuda
    bl _escrever_tex
    b nova_linha
2:
    mov w0, 0x0A
    bl _escrever_car
    ldr x0, = msg_status
    bl _escrever_tex
    b nova_linha
.section .rodata
comando: .asciz "~ $ "
msg_abrindo: .asciz "[Neon Script]: abrindo sessão...\n"
msg_ajuda: .asciz "[Comandos]:\ns: status do kernel\n"
msg_status: .asciz "[Kernel]: Neon 0.0.1\n[Arquitetura]: ARM64\n[Bibliotecas]: Neon Script 0.0.1\n"
