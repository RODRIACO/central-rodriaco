# Central Rodriaço

ERP interno da Rodriaço em **um único arquivo** (`index.html`), sem build e sem
biblioteca externa: Cadastros (famílias, componentes, itens com BOM), Comercial
(clientes, oportunidades, quadro de orçamentos com aprovações, pedidos), PCP
(ordens de produção, mapa de produção, área do operador com QR) e **Logística**.

## Logística › Análise CSV

Dashboard do mapa de produção do Cosmos. O caminho dos dados:

```
Cosmos ──(robo_coletor.py)──> bucket privado "dados-cosmos" do Supabase ──> Central Rodriaço
```

- O robô grava `DADOS COSMOS.csv` (OPs abertas, 31 colunas: local e data de entrega,
  endereço, cidade e UF reais, vendedor, NF e data de faturamento) no bucket
  `dados-cosmos`. A página lê as colunas pelo nome e ainda abre o arquivo antigo
  de 21 colunas.
- A página entra no Supabase com **e-mail e senha** (as mesmas contas do Estoque
  Livre), baixa o arquivo e monta o painel. A cada 5 minutos confere se o robô
  enviou um arquivo novo e recarrega sozinha.
- Filtros: período (por embarque, entrega, abertura ou faturamento), UF, cidade
  (acompanha a UF), local de entrega, cliente, vendedor, tipo de produto, etapa
  atual, busca livre e atalhos (vencidos, sem local, sem data, com NF). Clicar em
  qualquer barra, indicador ou coluna do gráfico filtra o painel inteiro.
- Gráficos: etapa, tipo, UF, cidades, vendedores, local de entrega e clientes.
  A tabela traz endereço, cidade, UF, vendedor, NF e data de faturamento.
- Tabela com paginação e **Exportar CSV** do que está filtrado.
- **Filtro por coluna estilo planilha:** o botão ▼ de cada cabeçalho abre ordenar
  (A→Z, mais antigo/recente, menor/maior), pesquisa, lista de valores com contagem,
  Selecionar tudo / Limpar e OK. Os filtros de coluna se somam aos do painel e
  indicadores e gráficos acompanham. O mesmo ▼ existe em todas as listas do ERP
  (Famílias, Componentes, Itens, Clientes, Pedidos, Ordens, Interações).
- **Clientes com grafias diferentes viram um só** (S A, S.A., SA, S/A, LTDA, acento,
  hífen): fica o nome que mais aparece. Vale só aqui; a Análise de Pedidos não muda.

### OP e linha

O código da OP no Cosmos tem 8 dígitos: os **5 primeiros são a OP (ordem), igual ao
número do pedido**, e os **3 últimos são a linha** dela (38421001 = OP 38421, linha
001). A tela mostra a OP só com os 5 dígitos e a linha à parte; "OPs abertas" conta
ordens (625 hoje) e "Linhas de OP" conta as linhas (3.187). Vale também na Análise de
Pedidos do Comercial.

**Indicadores e gráficos da Análise CSV contam OPs.** Embarque, local, cliente, UF e
vendedor são da OP inteira (em todas as OPs, todas as linhas têm o mesmo embarque), então
"OPs com embarque vencido" = 361 de 668 OPs, com as 1.560 linhas na observação. Só
**Etapa atual** e **Tipo de produto** contam linhas, porque variam de item para item (o
título do gráfico diz "OPs" ou "linhas").

### Tela Itens (seletor **OPs | Itens** no topo)

Soma os itens das **OPs abertas** com os mesmos filtros do painel (cliente, tipo de
produto, UF, datas, etapa, busca). Ex.: cliente Sodexo + tipo Balcões Neutros = 391 un.,
74 itens, 72 pedidos, 198 OPs.

- **Agrupar por:** Item, Cliente › Item, Tipo › Item ou Pedido › Item (subtotal por
  grupo e total geral). A coluna **Tipo** do Cosmos é a família do item; procurar
  "neutro" no nome perderia balcões como "UTE TAL" e "MIX".
- Por item: código Cosmos, quantidade total, nº de OPs, nº de linhas, primeiro e
  último embarque e quantidade com embarque vencido. Clicar no item abre as OPs.
- Os totais somam **só peças (PC e UN)**; itens em m² ou outra unidade aparecem na lista
  com a unidade, mas não entram na soma.
- **Imprimir:** abre um relatório A4 paisagem (marca, data/hora, data do arquivo do
  Cosmos, filtros usados, subtotais, total geral, cabeçalho repetido em cada página).
  Opções: mostrar os pedidos de cada item; uma página por grupo. "Salvar como PDF" na
  janela de impressão gera o PDF. Exportar CSV traz o mesmo agrupamento.

## Comercial › Análise de Pedidos

Cruza o **Relatório de Pedidos** do Cosmos (`Relatorio de Pedidos.csv`, todos os
pedidos desde 2017, sem valores) com as **OPs abertas** (`DADOS COSMOS.csv`) e com o
**histórico de OPs concluídas** (`OPs concluidas.csv`). Os arquivos vêm dos robôs pelo
mesmo bucket `dados-cosmos`: o robô da fábrica (de hora em hora) grava o Relatório de
Pedidos e as OPs abertas; o robô na nuvem (repositório privado `RODRIACO/ROBO-COSMOS`,
GitHub Actions, 1x por dia às 20:00) acumula as OPs concluídas.

- Uma linha por pedido (pedido com várias NFs vira uma linha só). Pedido = OP = 5
  primeiros dígitos do código; os 3 últimos são a linha. No detalhe aparece
  "OP 38421 — aberta · 5 linhas" e a tabela de linhas (001, 002...). OP de pedido que ainda não está no relatório aparece
  como "Fora do relatório".
- Situações: L Liberado, P Faturado Parcial, O Orçamento, B Bloqueado, E Expedido,
  F Faturado Total, C Cancelado, D Devolução. Padrão: Liberado + Faturado Parcial,
  pedidos a partir de 06/2025 (caixa "Mostrar pedidos antigos" traz o resto).
- Coluna **OP**: OP aberta / OP concluída / Sem OP. O objetivo é saber quais pedidos
  **chegaram ao PCP** (quem gera as OPs), então vale qualquer OP, aberta ou concluída.
- Indicadores clicáveis: liberado que chegou ao PCP, liberado sem OP (aguardando PCP),
  liberado com OP aberta, liberado só com OP concluída (o pedido segue Liberado com a
  produção pronta: em geral o faturamento gerou outro número de pedido), liberado com
  entrega vencida, faturado parcial com/sem OP, OP aberta em situação errada
  (orçamento, cancelado, faturado total, fora do relatório) e embarque depois da entrega.
- Gráficos clicáveis: pedidos por mês, situação, dias desde o pedido, vendedores,
  clientes, UF e etapa mais atrasada. Tabela com filtro por coluna; clicar no
  pedido abre as OPs dele. Exportar CSV.
- Aviso quando o Relatório de Pedidos tem mais de 3 horas (robô parado).
- Avisos: histórico de concluídas com mais de 36 horas (robô das 20:00 parado) e
  histórico não encontrado (a tela volta a mostrar só "sem OP aberta", que então
  inclui pedido com OP já concluída).
- **Limite:** o histórico de concluídas começa em 06/01/2025 (a tela mostra a faixa
  coberta); pedido mais antigo que isso pode aparecer como "Sem OP".
- Acesso: subárea Comercial › Análise de Pedidos. Rodar o `banco_analise_pedidos.sql`
  no Supabase antes de publicar (ele libera a leitura do bucket para essa subárea).

## Apps de suporte

Módulo **Apps de suporte**: apps da casa que ficam no mesmo site da Central. Cada um é
uma página irmã em `apps/<nome>/` e **abre em uma aba própria** (o item do menu e o
cartão do módulo abrem a nova aba). Hoje: **Estoque Livre** (`apps/estoque-livre/`) e
**Controle de Ferramentas** (`apps/ferramentas/`), cópias dos apps que estão no
Cloudflare (dados no mesmo Supabase), e **Controle de Empréstimos**
(`apps/emprestimos/`).

- **Controle de Ferramentas — só o administrador altera.** Dentro da Central os demais
  níveis (`estoque`, `comercial`) só consultam: sem cadastro, edição, troca, importação,
  nem movimentação. Os valores em R$ continuam só para administrador (tabelas separadas
  no banco). A regra vale na tela da cópia; para valer também no **banco** (e no app
  antigo do Cloudflare, que usa o mesmo banco), rode **uma vez** o
  `banco_ferramentas_admin.sql` no SQL Editor do Supabase. Depois dele, quem não é
  administrador recebe "Somente o administrador altera as ferramentas." ao tentar gravar.

- **Controle de Empréstimos** (`apps/emprestimos/`, permissão `apps.emprestimos`):
  empréstimos e adiantamentos de funcionários (parcelas, juros, baixas e descontos
  parciais, dashboard, impressão, log). É o `controle de emprestimos.html` que usava
  arquivo `.json` local, agora **com os dados no Supabase**. Dados pessoais (nome, folha,
  dívida): o código do site **não leva nenhum nome nem valor**, e o banco só devolve linhas
  a administrador ou a conta com a caixinha marcada em Contas. Passos, uma vez:
  1. rodar o `banco_emprestimos.sql` no SQL Editor (tabelas `emp_*`, regras e log
     imutável);
  2. rodar a carga inicial (`dados-iniciais.sql`, gerado do `.json` do app antigo por
     `gerar_dados.py`; fica **fora do GitHub**, na pasta `emprestimos-nuvem` do
     computador; recusa-se a rodar se o banco já tiver empréstimos);
  3. em Contas, marcar Apps de suporte › Controle de Empréstimos para quem lança.
  O app guarda objetos JSON (`dados`) com `versao` por linha: só grava o que mudou e,
  se outra pessoa mexeu na mesma linha, pergunta se recarrega ou sobrescreve. Atualiza a
  tela sozinho a cada minuto (quando está parada), mostra "SEM CONEXÃO — NÃO ESTÁ
  GRAVANDO" quando cai a rede e tenta de novo. O nome em cada lançamento e no log vem do
  login (`perfis.nome`). Baixar cópia de segurança (.json) e Compartilhar dashboard
  (arquivo de leitura) continuam.

- **Canal de Denúncia** (`apps/canal-denuncia/`, **sem caixinha em Contas**): canal
  anônimo exigido pela NR-1 (item 1.4.1.1) e pela Lei 14.457/2022. **É diferente dos
  outros apps, de propósito:**
  - As telas **Denunciar** e **Acompanhar** são públicas, **sem login**, e nunca leem a
    sessão da Central (falam com o banco por `fetch` só com a chave pública). É o
    endereço que vai no QR code do informativo: `.../apps/canal-denuncia/`.
  - O **painel** (`.../apps/canal-denuncia/#rh`) tem **login próprio**, guardado só
    enquanto a aba está aberta (`sessionStorage`, chave `canal-denuncia-rh`). Estar
    logado na Central não abre o painel.
  - **Não existe caixinha em Contas** para este app (`SUBS_TRAVADAS` no `index.html`),
    para ninguém ser marcado por engano. O atalho aparece sozinho para o administrador e
    para quem o banco diz que está liberado (a Central chama `denuncia_papel()` ao
    entrar). Nenhum e-mail fica escrito no código, que é público.
  - Quem lê denúncia é decidido no banco, pela tabela `denuncia_acesso` (`rh` = tudo
    menos o que envolve o RH; `direcao` = tudo), mexida só pelo SQL Editor. O
    administrador da Central vê o atalho, mas não lê denúncia: o painel responde
    "Sem acesso".
  - O banco não guarda IP, aparelho nem usuário; o protocolo é sorteado no celular e só
    o resumo (hash) dele é gravado; fotos saem sem EXIF.
  Passos, uma vez:
  1. rodar o `banco_canal_denuncia.sql` no SQL Editor (tabelas `denuncia*`, regras,
     funções públicas e o balde privado `denuncias`);
  2. criar os usuários em Authentication › Users e rodar o `acessos.sql` (tem e-mails;
     fica **fora do GitHub**, na pasta `canal-denuncia-app` do computador).
  Para incluir ou tirar alguém depois: só pelo `acessos.sql`.
  Para ver sem gravar nada: `.../apps/canal-denuncia/?demo=1`. Materiais impressos
  (Manual do Gestor e Informativo da Fábrica) ficam na pasta `canal-denuncia` do
  computador.

- **Login único:** Central e apps guardam o login na mesma chave do `localStorage`
  (`central_rodriaco_sb_v1`, mesmo site). Quem entrou em um abre o outro já logado;
  entrar pelo próprio app também vale para a Central. **Sair** em qualquer um sai nos
  dois (as outras abas percebem pelo evento `storage`). O Sair só encerra a sessão
  deste navegador no Supabase (`scope=local`); outros aparelhos continuam logados.
- **Renovação do token:** quem estiver aberto renova, um de cada vez
  (`navigator.locks`), e quem chega depois usa a sessão já renovada. O app não deixa a
  biblioteca do Supabase renovar sozinha (cliente de dados com `accessToken` e outro
  cliente só para entrar), para duas abas não gastarem o mesmo refresh token.
- **Permissão de abrir:** subárea `apps.estoque_livre` na janela Permissões de Contas.
  Dentro do app, os papéis dele (admin, estoque, comercial; `perfis.papel`) continuam
  decidindo quem edita — é o que protege os dados no banco.
- **Aberto direto** (`.../apps/estoque-livre/`) sem login na Central, o app mostra o
  próprio login e o guarda na mesma chave.
- **Novo app:** colocar a pasta em `apps/<nome>/`, acrescentar em `APPS_SUPORTE` e em
  `SUBMENUS.apps` no `index.html` e fazer o app usar a sessão compartilhada como o
  Estoque Livre faz (`CHAVE_SESSAO`, `sessaoValida`, `renovarSessao`).
- **Etiquetas com QR:** o QR do Estoque Livre aponta para o endereço de onde a
  etiqueta foi gerada. As já impressas apontam para o Cloudflare; **não desligue o
  Cloudflare** enquanto houver etiqueta antiga em uso.
- A versão da Central é a "verdade" do app; o repositório antigo `estoque-livre` fica
  só como histórico enquanto o Cloudflare estiver no ar.

## Acesso (login e contas)

O ERP inteiro fica atrás do login do Supabase, não só a Análise CSV:

- Ao abrir, pede **e-mail e senha** (contas do Supabase Auth, as mesmas dos outros
  apps da casa).
- Só entra conta **ativa** e com **ao menos um módulo liberado**. Conta ativa sem
  módulo vê "Sem módulos liberados"; conta desativada vê "Aguardando liberação".
- O menu e o painel inicial mostram só os módulos da pessoa. Administrador
  (`perfis.papel = 'admin'`) acessa tudo.
- Rodapé do menu mostra o e-mail e o botão **Sair**. A mesma sessão serve para a
  Análise CSV.
- A Área do Operador (inclusive pelo QR da OP) é um módulo à parte, "Área do
  Operador", e também precisa de liberação.

### Sessão e inatividade

- **1 hora sem uso encerra a sessão**, inclusive com a Central **fechada**: quem abrir depois de
  mais de 1 hora sem mexer em nada cai na tela de login ("Sessão encerrada: mais de 1 hora sem
  uso"). Aberta e parada, ela sai sozinha ao completar 1 hora.
- O relógio é uma chave do `localStorage` (`central_rodriaco_atividade_v1`) **dividida com os
  apps**: usar a Central, o Estoque Livre, as Ferramentas ou os Empréstimos mantém todos
  logados. Contam clique, tecla, rolagem e toque; a atualização automática dos dados **não**
  conta (senão uma tela esquecida aberta nunca venceria).
- Ao vencer, a sessão é encerrada também no Supabase (`scope=local`). No Controle de Empréstimos,
  o que ainda não foi gravado é enviado antes de sair.
- O tempo fica em `INATIV.ms` (Central) e `INATIV_MS` (apps).

### Instalar como app (Central)

Chrome/Edge: botão **Instalar** na barra de endereço (ou menu › Instalar Central Rodriaço) cria o
atalho na Área de Trabalho e no menu Iniciar, com o ícone **R**. Android: "Instalar app"; iPhone:
"Adicionar à tela de início". Arquivos: `manifest.json`, `sw.js` (service worker **sem cache**,
só habilita a instalação; ninguém fica preso em versão velha) e `icones/` (512, 192, 180 do iPhone,
`icone-mask-512` para o Android recortar, `favicon.ico`/`favicon-32.png` só com o R, sem a moldura).
O ícone também está no menu, na tela de login e no cabeçalho das impressões da Central.

### Esqueci minha senha / definir nova senha

- Na tela de login, **Esqueci minha senha** pede o e-mail e o Supabase manda um link
  (vale 1 hora, uso único). O botão *Send password recovery* do painel
  (Authentication › Users) manda o mesmo e-mail.
- O link abre a Central com o acesso temporário no `#` da URL (`type=recovery`) e ela
  mostra **Definir nova senha** (mínimo de 8 caracteres), grava com `PUT /auth/v1/user`
  e já entra logada. Link vencido ou já usado mostra "Link inválido ou vencido" com
  "Pedir novo link". A senha vale para a Central e para os apps (login único).
- **Configuração no Supabase (uma vez):** Authentication › URL Configuration › *Site URL*
  = `https://rodriaco.github.io/central-rodriaco/` e o mesmo endereço em *Redirect URLs*.
  Sem isso o e-mail aponta para o endereço antigo do Cloudflare.
- Se um link de recuperação cair no Estoque Livre ou no Controle de Ferramentas, o app
  repassa para a Central (`type=recovery` / `error_code=` no `#`). O `#i=CODIGO` do QR
  das etiquetas não é afetado.

### Contas (só administrador)

Módulo **Contas**: lista todas as contas, com o resumo do que cada uma acessa,
perfis rápidos (PCP, Comercial, Logística, Operador, Todos, Nenhum), botão
Ativar/Desativar e o botão **Permissões**: janela com os módulos e, embaixo de cada
um, as subáreas. Marcar o módulo marca todas as subáreas; é só desmarcar as que a
pessoa não deve ver (ex.: Cadastros só com Itens). O menu mostra só o liberado e o
módulo abre direto na primeira subárea permitida. Vale no próximo login da pessoa.

- **Criar conta:** Supabase › Authentication › Users › Add user (marque *Auto
  Confirm User*). Ela aparece na lista sem nenhum módulo.
- **Desligue o cadastro aberto** (Authentication › Sign In / Providers › *Allow new
  users to sign up*). Com ele ligado, qualquer e-mail do domínio liberado em
  `config.dominios` do Estoque Livre se cadastra sozinho e entra ativo.
- **Novo administrador:** hoje só pelo SQL Editor
  (`update public.perfis set papel = 'admin' where email = '...'`, com o gatilho
  `perfis_protege_papel` desligado durante o comando — veja o fim do `banco_acessos.sql`).
- Os acessos ficam em `public.acessos_erp` como chaves `modulo` (inteiro) ou
  `modulo.sub` (uma subárea, ex.: `cadastros.itens`); `tem_acesso(modulo, nivel)` é
  a função que as regras do banco usam (aceita `logistica.csv`). A tela liga/desliga; o banco já aceita
  "ver" e "editar" para quando cada app passar a usar níveis.
- Contas, papéis e situação vivem em `public.perfis`, compartilhada com o Estoque
  Livre e o Controle de Ferramentas. A Central **não altera** `papel` de ninguém.

**Leitura dos dados:** o local de entrega (`PedidoEndTipo`) é texto livre, quase
sempre o nome da unidade/cliente; cidade e UF vêm do cadastro (`CidadeNome`,
`EstadoUF`). Datas `01/01/1753`, `01/01/1900` e `01/01/2000` significam "sem
data". "Embarque vencido" é OP ainda aberta no Cosmos com embarque antes de hoje:
se já tem NF emitida provavelmente já saiu e só espera a baixa; as **sem NF** são
os atrasos de verdade (o painel mostra os dois números).

## Colocar no ar (GitHub Pages)

1. Suba `index.html` e este `README.md` na raiz do repositório
   (sugestão: `RODRIACO/central-rodriaco`).
2. Em **Settings › Pages**, escolha *Deploy from a branch* › `main` › `/ (root)`.
3. No Supabase (SQL Editor), rode **uma vez** o `banco_acessos.sql` (antes do
   primeiro login na versão nova — sem ele o ERP mostra erro ao entrar). Ele cria a
   tabela de acessos, deixa o bucket do CSV privado, exige o módulo Logística para
   ler o arquivo e garante `pcp1@mrinox.com.br` como administrador.
4. Confira: abrir o endereço público do arquivo, sem login, tem que dar erro.

O `banco_acessos.sql` substitui o antigo `banco_logistica.sql` (removido): rodar o
antigo depois do novo devolveria a regra "qualquer conta ativa lê o CSV". Ele só
roda no Supabase e não tem segredo.

## Segurança

- `index.html` carrega só a **chave anon** do Supabase (pública por desenho). A
  proteção do arquivo está na regra do bucket, não em esconder a chave.
- A service key do robô **nunca** vai para este repositório.
- O login é o do Supabase Auth; a sessão fica no navegador (`localStorage`) e
  o botão **Sair** apaga.
- **O login do ERP é uma porta de tela, não segurança de dados:** o `index.html`
  é público no Pages e cadastros/pedidos ficam no navegador de cada PC. Esconder
  um módulo é só tela. Protegidos de verdade (regra no Supabase): a Análise CSV
  (bucket privado + `tem_acesso('logistica')`) e a gestão de contas (só admin).
  Proteger os dados do ERP exige levá-los para o Supabase com RLS.

## Onde ficam os dados do ERP

Fora do artefato do Claude, cadastros, orçamentos e pedidos são salvos **no
navegador de quem está usando** (`localStorage`). Cada computador tem os seus
dados. Compartilhar entre a equipe exige levar o ERP para o Supabase — etapa
futura, ainda não feita.

## Configuração

No começo do bloco `LOG_CFG` do `index.html`: URL do projeto, chave anon, nome do
bucket e do arquivo.
