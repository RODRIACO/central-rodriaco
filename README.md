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

## Apps de suporte

Módulo **Apps de suporte**: apps da casa que ficam no mesmo site da Central. Cada um é
uma página irmã em `apps/<nome>/` e **abre em uma aba própria** (o item do menu e o
cartão do módulo abrem a nova aba). Hoje: **Estoque Livre** (`apps/estoque-livre/`,
cópia do app que está no Cloudflare; os dados continuam no mesmo Supabase).

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
