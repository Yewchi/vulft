## VULFT


VULFT - Total Override Bot Script. Comportamento de luta altamente dinâmico. As funções do DotaBuff e as sequências de construção de inventário são atualizadas em: 19/03/23. Requer instalação manual na pasta vscripts/bots (o mesmo que o Phalanx Bot e outros bots recentes, devido a um bug do workshop Dota). A VUL-FT não é afiliada à DotaBuff.



##  Tradução 

A tradução leva muito tempo para mim, cerca de 30 minutos. Preciso voltar à programação, então esse arquivo pode estar desatualizado. Se o processo de instalação manual for corrigido e não for mais necessário, atualizarei este documento. Consulte a página do workshop em inglês para a data de compilação atual do DotaBuff e a data de lançamento do software.



##  Instalação manual 

Atualmente, o VUL-FT não funcionará apenas assinando. Ele será revertido para os bots padrão, outros bots lançados recentemente têm o mesmo problema. Por enquanto, é necessário instalar manualmente os bots.



Opcional: Antes de definir o VUL-FT como o script de desenvolvimento local, também pode ser uma boa ideia fazer backup de sua antiga pasta 'vscript/bots' se você tiver outro bot armazenado lá:

A pasta do bot de desenvolvimento local está localizada em

[unidade]:/%Arquivos de Programas%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots

0) renomeie a pasta bots para bots.old.

1) criar uma nova pasta chamada bots

2) copie os arquivos VUL-FT do github ou da pasta do workshop para a nova pasta de bots.



-- Através de arquivos locais de oficina: (os arquivos de oficina verificados pela Valve)

Depois de baixar o VULFT no jogo ou no workshop, encontre a pasta recente em

[unidade]:/%Arquivos de Programas%/Steam/steamapps/workshop/content/570/2872725543

e copie o conteúdo dessa pasta para a pasta bots em 

[unidade]:/%Arquivos de Programas%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/



-- Via Github: (atualizado pelo criador)

Se você souber como usar o git, você pode baixar manualmente os bots do [official VUL-FT Github](https://github.com/yewchi/vulft) e colocá-los em

[unidade]:/%Arquivos de Programas%/Steam/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/



-- Iniciando uma partida:

Depois que uma das etapas acima estiver concluída, você poderá executar os bots navegando no jogo para Lobbies personalizados -> Criar -> Editar:

Em BOT SETTINGS, altere os bots da equipe para o Local Dev Script (se você ainda quiser lutar contra os bots da Valve, observe que há uma opção para "Default Bots" aqui também)

Altere LOCALIZAÇÃO DO SERVIDOR para HOST LOCAL (seu computador).

A configuração "Fácil" ou "Injusta" ainda não tem efeito, mas "Injusta" pode aumentar o ouro passivo do bot.

Pressione OK.

Junte-se ao primeiro slot de Dire ou Radiant.

Pressione START GAME.



Alternativamente, você pode usar a opção "Play VS Bots", mas nem todos os heróis são implementados.



## Características

- Luta dinâmica na tomada de decisões.

- Mais como jogadores reais.

- Os bots começam a se mover imediatamente após os bots liberarem um ataque, caminhando em direção à retirada do inimigo.

- Gestão avançada de estoques.

- Locais de ala de observadores gerados automaticamente, para se o mapa mudar.

- Analisador DotaBuff para uma média de 5 habilidades de jogo, papéis e um item construído por jogadores de Divine - Immortal naquela semana.

- Caça básica a monstros no tempo livre dos bots.

- Quando eles têm pontos de vida baixos e estão em perigo, eles podem atacar monstros da selva.

- Retirada dinâmica, para torres amigáveis (a menos que a torre fique muito lotada), ou para aliados amigáveis na direção da fonte aliada.

- Alocação de tarefas de runas de recompensa com base na proximidade, segurança, neblina, classificação de ganância - Alocação de defesa de torre com base na dificuldade de luta.

- Menor uso da CPU do que outros bots populares.

- Bugs de software!



Mas também, prometo que o código deste projeto é 100% funcional offline e nunca introduzirei a API de rede nesta base de código.



##  Relatório de Erros 

[ Lua Error Dump (link de discussão do steam)](https://steamcommunity.com/workshop/filedetails/discussion/2872725543/3648503910213521285/) -- Use isso se quiser copiar apenas algumas mensagens de erro do log do console.

[ Código-fonte VUL-FT](https://github.com/yewchi/vulft) -- Github público



##  Problemas conhecidos 

Esta seção é bastante difícil de traduzir, desculpe!



Todas as novas entidades grabbable de recompensas de ouro e entidades de rios de água introduzidas em algum momento no 7.x atualmente não podem ser captadas por scripts de bot de substituição total. Isso inclui o recurso mais recente de entidades de recompensa empilhadas umas sobre as outras. Além disso, apenas a entidade de recompensa exibida mais recentemente pode ser coletada. Uma solução alternativa está em vigor antes do trombone de guerra às 0:00 para permitir que os bots os peguem, no entanto, a solução alternativa faz com que os bots percam o controle total de seu inventário, e por isso é removido após a buzina por volta das 0:30



##  Estado do projeto 

Versão alfa. Por favor, dê feedback.

O projeto está atualmente estável: Estável, sem falhas de jogo ou script quebrando mais de 10 partidas a partir de 30/03/23 (30 de março)

Última atualização da meta do DotaBuff: Por favor, verifique as datas da página do workshop, mas está em inglês.



##  Contato de desenvolvimento 

zyewchi@gmail.com

