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

- O robô grava `DADOS COSMOS.csv` (OPs abertas + `LocalEntrega` e `PedidoDataEntrega`
  vindos do FBX Data Entrega) no bucket `dados-cosmos`.
- A página entra no Supabase com **e-mail e senha** (as mesmas contas do Estoque
  Livre), baixa o arquivo e monta o painel. A cada 5 minutos confere se o robô
  enviou um arquivo novo e recarrega sozinha.
- Filtros: período (por embarque, entrega ou abertura), UF, local de entrega,
  cliente, tipo de produto, etapa atual, busca livre e atalhos (vencidos, sem
  local, sem data). Clicar em qualquer barra, indicador ou coluna do gráfico
  filtra o painel inteiro.
- Tabela com ordenação, paginação e **Exportar CSV** do que está filtrado.

## Acesso (login do ERP)

O ERP inteiro fica atrás do login do Supabase, não só a Análise CSV:

- Ao abrir, pede **e-mail e senha** — as mesmas contas do Estoque Livre.
- Só entra conta **ativa** (`public.meu_status()` = `ativo`). Conta pendente fica
  em "Aguardando liberação" até um administrador ativar no Estoque Livre.
- O ERP nem monta antes de liberar. A mesma sessão serve para a Análise CSV
  (não pede senha de novo). Rodapé do menu mostra o e-mail e o botão **Sair**.
- Contas se criam e se liberam no Estoque Livre; o ERP só faz o login.
- A Área do Operador (inclusive pelo QR da OP) também passa pelo login.

**Limite dos dados:** `LocalEntrega` é texto livre (quase sempre o nome da
unidade/cliente). A UF só aparece em cerca de 4 de cada 10 linhas; as demais
ficam como "Não informada". Datas `01/01/1753`, `01/01/1900` e `01/01/2000`
significam "sem data". "Embarque vencido" é OP ainda aberta no Cosmos com
embarque antes de hoje — pode já ter embarcado e estar só esperando a baixa.

## Colocar no ar (GitHub Pages)

1. Suba `index.html` e este `README.md` na raiz do repositório
   (sugestão: `RODRIACO/central-rodriaco`).
2. Em **Settings › Pages**, escolha *Deploy from a branch* › `main` › `/ (root)`.
3. No Supabase (SQL Editor), rode **uma vez** o `banco_logistica.sql`. Ele deixa o
   bucket privado e libera a leitura só para conta logada e ativa.
4. Confira: abrir o endereço público do arquivo, sem login, tem que dar erro.

O `banco_logistica.sql` não precisa ficar no repositório — ele só roda no
Supabase. Se preferir manter, não tem segredo nele.

## Segurança

- `index.html` carrega só a **chave anon** do Supabase (pública por desenho). A
  proteção do arquivo está na regra do bucket, não em esconder a chave.
- A service key do robô **nunca** vai para este repositório.
- O login é o do Supabase Auth; a sessão fica no navegador (`localStorage`) e
  o botão **Sair** apaga.
- **O login do ERP é uma porta de tela, não segurança de dados:** o `index.html`
  é público no Pages e cadastros/pedidos ficam no navegador de cada PC. Só a
  Análise CSV é protegida de verdade (bucket privado + regra no Supabase).
  Proteger os dados do ERP exige levá-los para o Supabase com RLS.

## Onde ficam os dados do ERP

Fora do artefato do Claude, cadastros, orçamentos e pedidos são salvos **no
navegador de quem está usando** (`localStorage`). Cada computador tem os seus
dados. Compartilhar entre a equipe exige levar o ERP para o Supabase — etapa
futura, ainda não feita.

## Configuração

No começo do bloco `LOG_CFG` do `index.html`: URL do projeto, chave anon, nome do
bucket e do arquivo.
