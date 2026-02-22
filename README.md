# Neon
meu bootloader + kernel feito em Assembly ARM64 e FPB.

## feito:
* vetores de exceção configurados.
* MMU desativada temporariamente.
* svc configurada.

## drivers:
1. Terminal virt UART.
2. Disco VirtIO.
3. Vídeo Virt-GPU.

## bibliotecas:
1. Neon Script: uma biblioteca simples de comandos do terminal em FPB.

## extra:
agora tem suporte a FPB (Fácil Programação Baixo nivel) :D

digite 'a' no bootloader e '-ajuda' no kernel para saber os comandos.

## chamadas do sistema
## chamada de escrita:
* x0 = 1 // 2 significa escrever mensagem de erro
* x1 = buffer
* x2 = tamanho
* x8 = 64
* retorna os bytes escritos ou -9
: escreve na saida de texto.

## chamada de leitura:
* x0 = 0
* x1 = buffer
* x2 = quantidade caracteres maxima
* x8 = 63
* retorna os bytes lidos ou -9
: lê o texto do terminal.

## chamada de saida:
* x0 = 0 // código de saida
* x8 = 93 // ou 94
: encerra o processo e retorna pro kernel.