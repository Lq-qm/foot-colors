# foot-colors

Script para trocar as cores do terminal [foot](https://codeberg.org/dnkl/foot) a partir de um arquivo de tema em texto (`.txt`). Cria backup, substitui apenas os valores hexadecimais das cores e avisa para reiniciar o terminal.

## Arquivos do projeto

| Arquivo | Descrição |
|---|---|
| `foot-colors.sh` | Script principal (bash + awk) |
| `temas/` | 11 temas populares prontos (`.txt`) — veja a lista abaixo |
| `foot.ini` | Configuração de exemplo do foot (referência de formato) |

## Requisitos

- `bash` 4+
- `awk` (POSIX; testado com GNU Awk)
- `foot` instalado (para validar/aplicar as cores)

## Uso básico

```bash
./foot-colors.sh
```

Sem opções, aplica o tema padrão (**dracula**) no seu
`~/.config/foot/foot.ini`.

Opções:

```
-f, --foot-ini ARQ   Caminho do foot.ini (padrão: ~/.config/foot/foot.ini)
-T, --tema NOME      Tema da pasta temas/ pelo nome (ex.: -T gruvbox-dark)
-t, --theme ARQ      Caminho completo de um arquivo de tema .txt
-l, --list           Lista os temas disponíveis
-h, --help           Mostra a ajuda
```

Exemplos:

```bash
./foot-colors.sh -l                     # lista os temas disponíveis
./foot-colors.sh -T gruvbox-dark        # aplica o Gruvbox Dark
./foot-colors.sh -T tokyo-night         # aplica o Tokyo Night
./foot-colors.sh -t ~/temas/meu.txt     # usa um tema .txt em qualquer lugar
./foot-colors.sh -f ~/outro/foot.ini -T nord   # outro foot.ini + outro tema
```

### Temas disponíveis

| Nome | Estilo |
|---|---|
| `dracula` | escuro, roxo/rosa vibrantes (padrão) |
| `gruvbox-dark` | escuro, tons quentes retrô |
| `gruvbox-light` | claro, tons quentes |
| `github-dark` | escuro, cores oficiais do GitHub |
| `tokyo-night` | escuro, azul noturno |
| `nord` | escuro, paleta fria nórdica |
| `solarized-dark` | escuro, clássico de Ethan Schoonover |
| `solarized-light` | claro, clássico de Ethan Schoonover |
| `one-dark` | escuro, estilo Atom/VS Code |
| `monokai` | escuro, alto contraste |
| `catppuccin-mocha` | escuro, tons pastel |

Dica: `-T` aceita o nome com ou sem a extensão `.txt` (ex.: `-T dracula` ou
`-T dracula.txt`) e também aceita caminho de arquivo (`-T /caminho/para/tema.txt`).

### Exemplo de saída

```
✔ Cores do foot atualizadas com sucesso!
  • Arquivo modificado: /home/lo/.config/foot/foot.ini
  • Backup criado:      /home/lo/.config/foot/foot.ini.bkp
  • Cores alteradas:    18
  • Flags:              foreground background regular0 regular1 regular2 regular3 regular4 regular5 regular6 regular7 bright0 bright1 bright2 bright3 bright4 bright5 bright6 bright7

⚠ Para aplicar as novas cores, REINICIE O FOOT (feche e abra o terminal novamente).
```

Se nenhuma cor for alterada (ex.: cores já iguais ao tema, ou chaves não
existentes como linhas ativas), o script informa o que verificou e não muda
nada além do backup.

## Formato do arquivo de tema

Uma cor por linha, `chave=valor_hex` (sem `#` no valor):

```txt
# comentário — linhas com '#' e em branco são ignoradas
foreground=f8f8f2
background=282a36
regular0=282a36
bright4=d6acff
```

- Valores aceitos: hexadecimais de 3, 4, 6 ou 8 dígitos (ex.: `f8f8f2`, `282a36`).
  Valores com `#` inicial (ex.: `#f8f8f2`) também são aceitos e normalizados.
- Cores compostas podem ter mais de um token: `jump-labels=282a36 bd93f9`.
- Entradas inválidas (chave que não é cor, valor não hex, chave duplicada)
  são **ignoradas** e a quantidade é reportada ao final.

### Chaves válidas

`foreground`, `background`, `cursor`, `selection-foreground`,
`selection-background`, `flash`, `regular0`–`regular7`, `bright0`–`bright7`,
`dim0`–`dim7`, `sixel0`–`sixel15`, `jump-labels`, `scrollback-indicator`,
`search-box-no-match`, `search-box-match`, `urls`, e as cores `0`–`255` da
paleta estendida.

## Como o script garante a segurança

1. **Backup primeiro** — `foot.ini.bkp` é criado antes de qualquer alteração;
   se algo falhar, o original continua intacto.
2. **Só linhas de cor ativas** — apenas linhas `chave=valor` dentro das seções
   `[color]`, `[colors-dark]` ou `[colors-light]` são consideradas.
3. **Linhas comentadas não são tocadas** — uma linha `# regular0=...` nunca é
   descomentada nem alterada.
4. **Só valores hexadecimais** — valores que não são hex (ex.: `alpha=0.85`,
   `blur=yes`, `cursor=` vazio) são preservados.
5. **Nada mais é modificado** — nenhuma outra linha do `foot.ini` é criada,
   removida ou editada (comentários inline e espaçamento são preservados).
6. **Validação pós-escrita** — o número de linhas é conferido antes de gravar;
   o resultado pode ser checado com `foot -C` (exit 0 = config válida).

## Voltando ao estado anterior

```bash
# restaura a config de antes da última execução do script
cp ~/.config/foot/foot.ini.bkp ~/.config/foot/foot.ini
```

> Nota: cada execução **sobrescreve** o `.bkp` com o estado anterior daquela
> execução. Se quiser manter histórico, copie o `.bkp` para outro nome.

## Verificando que o foot aceita a config

```bash
foot -C            # valida a config padrão (~/.config/foot/foot.ini)
foot -C -c ARQ     # valida um arquivo específico
```

## Solução de problemas

| Sintoma | Causa provável / ação |
|---|---|
| `ERRO: tema 'x' não encontrado` | Rode `./foot-colors.sh -l` para ver os nomes exatos dos temas disponíveis |
| `ERRO: ... (o tema está em um formato válido?)` | Nenhuma entrada válida no tema — revise o formato `chave=valor_hex` |
| Nada foi alterado | As chaves do tema precisam existir como **linhas ativas** nas seções `[color]`/`[colors-dark]`/`[colors-light]` do foot.ini (linhas comentadas são ignoradas de propósito) |
| Cores não aparecem no terminal | Reinicie o foot — a config só é lida na inicialização |
| `foot: ... syntax error` ao abrir o terminal | A config foi corrompida fora do script (ex.: redirecionamento acidental `> foot.ini`). Restaure o backup: `cp foot.ini.bkp foot.ini` |

## Como criar seu próprio tema

1. Copie um tema existente como base (ex.: `cp temas/dracula.txt temas/meu-tema.txt`).
2. Substitua os valores hex (dica: `foot` exibe a paleta atual, ou use qualquer
   gerador de paletas — só copie os 6 dígitos hex de cada cor).
3. Rode `./foot-colors.sh -T meu-tema` (temas em `temas/` aparecem no `--list`).
4. Não gostou? `cp ~/.config/foot/foot.ini.bkp ~/.config/foot/foot.ini` e rode de novo.
