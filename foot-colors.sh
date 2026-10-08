#!/usr/bin/env bash
#
# foot-colors.sh — troca as cores do terminal foot a partir de um arquivo de tema (.txt)
#
# Fluxo:
#   1. Cria um backup (.bkp) do foot.ini;
#   2. Busca no foot.ini as flags (linhas ativas, não comentadas) de cores;
#   3. Substitui apenas os valores hexadecimais das cores encontradas pelos
#      valores definidos no arquivo de tema;
#   4. Exibe o resultado e pede ao usuário para reiniciar o foot.
#
# Regras de segurança:
#   - Somente linhas de cor ATIVAS (sem '#') dentro das seções [color],
#     [colors-dark] ou [colors-light] são modificadas;
#   - Linhas comentadas são preservadas exatamente como estão (NÃO são
#     descomentadas);
#   - Nenhuma outra linha/arquivo é alterada.
#
# Uso:
#   ./foot-colors.sh [opções]
#   ./foot-colors.sh -l                  # lista os temas disponíveis
#   ./foot-colors.sh -T gruvbox-dark     # aplica um tema da pasta temas/
#
set -euo pipefail

PROG=$(basename "$0")
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
FOOT_INI="${FOOT_INI:-$HOME/.config/foot/foot.ini}"
THEME_FILE=""
THEME_NAME=""
LIST_ONLY=0

usage() {
  cat <<EOF
Uso: $PROG [opções]

Troca as cores do terminal foot usando um arquivo de tema em texto (.txt).
Cria antes um backup do foot.ini (foot.ini.bkp) e, ao final, pede para
reiniciar o foot.

Opções:
  -f, --foot-ini ARQ   Caminho do foot.ini (padrão: ~/.config/foot/foot.ini)
  -T, --tema NOME      Tema da pasta temas/ pelo nome (ex.: -T gruvbox-dark)
  -t, --theme ARQ      Caminho completo de um arquivo de tema .txt
  -l, --list           Lista os temas disponíveis
  -h, --help           Mostra esta ajuda

Sem -T/-t, o tema padrão (temas/dracula.txt) é usado.

Formato do arquivo de tema (uma cor por linha, chave=valor hex):
  foreground=f8f8f2
  background=282a36
  regular0=282a36
  bright4=d6acff

Chaves válidas: foreground, background, cursor,
  selection-foreground, selection-background, flash,
  regular0..7, bright0..7, dim0..7, sixel0..15,
  jump-labels, scrollback-indicator, search-box-no-match,
  search-box-match, urls e as cores 0..255 da paleta estendida.

Linhas em branco e linhas iniciadas por '#' no tema são ignoradas.
Apenas valores hexadecimais (ex.: f8f8f2, opcionalmente com '#') são aceitos.
EOF
}

err()  { printf 'ERRO: %s\n' "$*" >&2; exit 1; }

# lista os temas .txt disponíveis (pasta temas/ e raiz do projeto)
list_themes() {
  local files=() f name desc
  for f in "$SCRIPT_DIR/temas/"*.txt "$SCRIPT_DIR/"*.txt; do
    [ -f "$f" ] || continue
    files+=("$f")
  done
  if [ "${#files[@]}" -eq 0 ]; then
    printf 'Nenhum tema .txt encontrado em %s ou %s\n' "$SCRIPT_DIR/temas" "$SCRIPT_DIR" >&2
    return 1
  fi
  printf 'Temas disponíveis (%s):\n\n' "${#files[@]}"
  for f in "${files[@]}"; do
    name=$(basename "$f" .txt)
    desc=$(sed -n 's/^[[:space:]]*#[[:space:]]*//p' "$f" | head -n 1)
    printf '  %-22s %s\n' "$name" "${desc:-sem descrição}"
  done
  printf '\nUso: %s -T <nome-do-tema>\n' "$PROG"
}

# resolve um nome de tema em um arquivo (caminho direto, temas/ ou raiz)
resolve_theme() {
  local nome=$1
  if [ -f "$nome" ]; then printf '%s' "$nome"; return 0; fi
  if [ -f "$SCRIPT_DIR/temas/$nome.txt" ]; then printf '%s' "$SCRIPT_DIR/temas/$nome.txt"; return 0; fi
  if [ -f "$SCRIPT_DIR/temas/$nome" ]; then printf '%s' "$SCRIPT_DIR/temas/$nome"; return 0; fi
  if [ -f "$SCRIPT_DIR/$nome.txt" ]; then printf '%s' "$SCRIPT_DIR/$nome.txt"; return 0; fi
  if [ -f "$SCRIPT_DIR/$nome" ]; then printf '%s' "$SCRIPT_DIR/$nome"; return 0; fi
  return 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    -f|--foot-ini) [ $# -ge 2 ] || err "a opção $1 requer um argumento"; FOOT_INI=$2; shift 2 ;;
    -T|--tema)     [ $# -ge 2 ] || err "a opção $1 requer um argumento"; THEME_NAME=$2; shift 2 ;;
    -t|--theme)    [ $# -ge 2 ] || err "a opção $1 requer um argumento"; THEME_FILE=$2; shift 2 ;;
    -l|--list)     LIST_ONLY=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *) err "opção desconhecida: $1 (use --help)" ;;
  esac
done

if [ "$LIST_ONLY" -eq 1 ]; then
  list_themes
  exit $?
fi

# tema escolhido pelo nome (-T) ou caminho (-t)
if [ -n "$THEME_NAME" ]; then
  if ! THEME_FILE=$(resolve_theme "$THEME_NAME"); then
    err "tema '$THEME_NAME' não encontrado (use --list para ver os disponíveis)"
  fi
fi

# tema padrão
if [ -z "$THEME_FILE" ]; then
  if [ -f "$SCRIPT_DIR/temas/dracula.txt" ]; then
    THEME_FILE="$SCRIPT_DIR/temas/dracula.txt"
  elif [ -f "$SCRIPT_DIR/foot-theme.txt" ]; then
    THEME_FILE="$SCRIPT_DIR/foot-theme.txt"
  else
    err "nenhum tema padrão encontrado; use -T <nome> ou -t <arquivo> (veja --list)"
  fi
fi

# ---------- validações iniciais ----------
[ -f "$FOOT_INI" ]   || err "foot.ini não encontrado: $FOOT_INI"
[ -r "$FOOT_INI" ]   || err "sem permissão de leitura: $FOOT_INI"
[ -w "$FOOT_INI" ]   || err "sem permissão de escrita: $FOOT_INI"
[ -f "$THEME_FILE" ] || err "arquivo de tema não encontrado: $THEME_FILE"
[ -r "$THEME_FILE" ] || err "sem permissão de leitura: $THEME_FILE"
command -v awk >/dev/null 2>&1 || err "awk não encontrado no sistema"

# ---------- 1) backup ----------
BACKUP="$FOOT_INI.bkp"
cp -p -- "$FOOT_INI" "$BACKUP" || err "não foi possível criar o backup: $BACKUP"

# ---------- 2/3) substituição das cores ----------
tmp=$(mktemp "${TMPDIR:-/tmp}/foot-colors.ini.XXXXXX") || err "falha ao criar arquivo temporário"
stats=$(mktemp "${TMPDIR:-/tmp}/foot-colors.stats.XXXXXX") || { rm -f "$tmp"; err "falha ao criar arquivo temporário"; }
trap 'rm -f "$tmp" "$stats"' EXIT

awk -v THEME="$THEME_FILE" -v STATS="$stats" '
# ---------------------------------------------------------------- funções ---
# token hex válido: 3, 4, 6 ou 8 dígitos hex (com ou sem "#")
function hexok(s) {
  if (substr(s, 1, 1) == "#") s = substr(s, 2)
  if (s == "") return 0
  if (s !~ /^[0-9a-fA-F]+$/) return 0
  l = length(s)
  return (l == 3 || l == 4 || l == 6 || l == 8)
}

# valor "de cor": um ou mais tokens hex separados por espaços
function colorlike(s,   n, t, i) {
  n = split(s, t, /[ \t]+/)
  if (n == 0) return 0
  for (i = 1; i <= n; i++) if (!hexok(t[i])) return 0
  return 1
}

# ------------------------------------------------------------------ BEGIN ---
BEGIN {
  # whitelist de chaves de cor do foot
  nk = split("foreground background cursor selection-foreground selection-background flash jump-labels scrollback-indicator search-box-no-match search-box-match urls", arr, " ")
  for (i = 1; i <= nk; i++) iscolor[arr[i]] = 1
  for (i = 0; i <= 7;  i++) { iscolor["regular" i] = 1; iscolor["bright" i] = 1; iscolor["dim" i] = 1 }
  for (i = 0; i <= 15; i++) { iscolor["sixel" i]   = 1 }

  # ---- lê e valida o arquivo de tema ----
  n_theme = 0; n_bad = 0
  while ((getline tline < THEME) > 0) {
    sub(/\r$/, "", tline)
    p = index(tline, "#")                       # ignora comentários no tema
    if (p > 0) tline = substr(tline, 1, p - 1)
    gsub(/^[ \t]+/, "", tline); gsub(/[ \t]+$/, "", tline)
    if (tline == "") continue
    e = index(tline, "=")
    if (e == 0) { n_bad++; continue }
    k = substr(tline, 1, e - 1)
    v = substr(tline, e + 1)
    gsub(/^[ \t]+/, "", k); gsub(/[ \t]+$/, "", k)
    gsub(/^[ \t]+/, "", v); gsub(/[ \t]+$/, "", v)

    # normaliza: remove "#" inicial de cada token
    nv = ""; m = split(v, tok, /[ \t]+/)
    for (i = 1; i <= m; i++) {
      if (substr(tok[i], 1, 1) == "#") tok[i] = substr(tok[i], 2)
      nv = (nv == "" ? tok[i] : nv " " tok[i])
    }
    if (k == "" || nv == "") { n_bad++; continue }

    tk = tolower(k)
    if (!(tk in iscolor) && !(tk ~ /^[0-9]+$/ && tk + 0 <= 255)) { n_bad++; continue }  # chave não é cor
    ok = 1
    for (i = 1; i <= m; i++) if (!hexok(tok[i])) { ok = 0; break }
    if (!ok) { n_bad++; continue }
    if (tk in tv) { n_bad++; continue }          # chave duplicada no tema
    tv[tk] = nv
    n_theme++
  }
  close(THEME)

  if (n_theme == 0) {
    printf "NREPL=0\nNSAME=0\nNBAD=%d\n", n_bad > STATS
    close(STATS)
    exit 2
  }
}

# -------------------------------------------------------------------- corpo ---
{
  sub(/\r$/, "")
  line = $0

  # linha comentada -> preserva intacta (não descomentar, nem alterar)
  if (line ~ /^[ \t]*#/) { print line; next }

  # cabeçalho de seção -> controla se estamos numa seção de cores
  if (line ~ /^[ \t]*\[/) {
    s = line
    sub(/^[ \t]*\[/, "", s)
    sub(/\].*/, "", s)
    gsub(/[ \t]/, "", s)
    incolor = (tolower(s) == "color" || tolower(s) == "colors-dark" || tolower(s) == "colors-light")
    print line
    next
  }

  # fora das seções de cor -> não tocar
  if (!incolor) { print line; next }

  # linha ativa "chave=valor"
  if (!match(line, /^[ \t]*[A-Za-z0-9][A-Za-z0-9-]*[ \t]*=[ \t]*/)) { print line; next }

  key = substr(line, 1, RLENGTH)
  sub(/[ \t]*=.*/, "", key)
  gsub(/[ \t]/, "", key)
  key = tolower(key)

  if (!(key in tv)) { print line; next }        # cor não definida no tema

  rest = substr(line, RLENGTH + 1)               # valor + eventual comentário
  t = rest; sub(/^[ \t]+/, "", t)

  if (substr(t, 1, 1) == "#") {                  # valor pode vir com "#" (ex.: #f8f8f2)
    if (match(t, /^#[0-9a-fA-F]+/) && hexok(substr(t, 1, RLENGTH))) {
      val = substr(t, 1, RLENGTH); tail = ""; comment = substr(t, RLENGTH + 1)
    } else { print line; next }                  # era só comentário -> não tocar
  } else {
    p = index(rest, "#")
    rawval = (p > 0 ? substr(rest, 1, p - 1) : rest)
    comment = (p > 0 ? substr(rest, p) : "")
    # separa a "cauda" (espaços antes do comentário / ao final da linha) para preservá-la
    t2 = rawval; gsub(/[ \t]+$/, "", t2)
    tail = substr(rawval, length(t2) + 1)
    val = t2
  }

  if (val == "") { print line; next }
  if (!colorlike(val)) { print line; next }      # valor atual não é hex -> não tocar

  val_cmp = (substr(val, 1, 1) == "#" ? substr(val, 2) : val)
  if (val_cmp == tv[key]) { n_same++; print line; next }   # já está com a cor do tema

  print substr(line, 1, RLENGTH) tv[key] tail comment
  n_repl++
  if (!(key in seen)) { seen[key] = 1; keys[++n_keys] = key }
}

# ---------------------------------------------------------------------- END ---
END {
  printf "NREPL=%d\n", n_repl + 0   > STATS
  printf "NSAME=%d\n",  n_same + 0  > STATS
  printf "NBAD=%d\n",   n_bad + 0   > STATS
  for (i = 1; i <= n_keys; i++) printf "KEY=%s\n", keys[i] > STATS
  close(STATS)
}
' "$FOOT_INI" > "$tmp" || {
  rm -f "$tmp" "$stats"
  err "falha ao processar os arquivos (o tema está em um formato válido?)"
}

# ---------- sanidade: nenhuma linha deve ser criada/removida ----------
# (awk END{NR} conta registros independentemente de newline final)
if [ "$(awk 'END { print NR }' "$tmp")" -ne "$(awk 'END { print NR }' "$FOOT_INI")" ]; then
  rm -f "$tmp" "$stats"
  err "resultado inesperado (nº de linhas alterado); o foot.ini NÃO foi modificado (backup em $BACKUP)"
fi
[ -s "$tmp" ] || err "arquivo de saída vazio; abortando sem alterar o foot.ini"

# aplica a mudança (mantém inode/permissões do original)
cat -- "$tmp" > "$FOOT_INI" || err "falha ao escrever em $FOOT_INI"

# ---------- 4) mensagem final ----------
n_repl=0; n_same=0; n_bad=0; keys=""
while IFS= read -r l; do
  case "$l" in
    NREPL=*) n_repl=${l#NREPL=} ;;
    NSAME=*) n_same=${l#NSAME=} ;;
    NBAD=*)  n_bad=${l#NBAD=}  ;;
    KEY=*)   keys="$keys ${l#KEY=}" ;;
  esac
done < "$stats"

# caminho do tema de forma legível (relativo ao projeto, se possível)
theme_display=$THEME_FILE
case "$theme_display" in
  "$SCRIPT_DIR"/*) theme_display=${theme_display#"$SCRIPT_DIR"/} ;;
esac

if [ "$n_repl" -gt 0 ]; then
  printf '✔ Cores do foot atualizadas com sucesso!\n'
  printf '  • Arquivo modificado: %s\n' "$FOOT_INI"
  printf '  • Backup criado:      %s\n' "$BACKUP"
  printf '  • Tema:               %s\n' "$theme_display"
  printf '  • Cores alteradas:    %s\n' "$n_repl"
  printf '  • Flags:             %s\n' "$keys"
  if [ "$n_same" -gt 0 ]; then
    printf '  • Já estavam corretas: %s\n' "$n_same"
  fi
  if [ "$n_bad" -gt 0 ]; then
    printf '  • Entradas inválidas ignoradas no tema: %s\n' "$n_bad"
  fi
  printf '\n'
  printf '⚠ Para aplicar as novas cores, REINICIE O FOOT (feche e abra o terminal novamente).\n'
else
  printf 'ℹ Nenhuma cor foi alterada no foot.ini.\n'
  printf '  • Arquivo verificado: %s\n' "$FOOT_INI"
  printf '  • Backup criado:      %s\n' "$BACKUP"
  printf '  • Tema:               %s\n' "$theme_display"
  if [ "$n_same" -gt 0 ]; then
    printf '  • Cores já estavam iguais ao tema: %s\n' "$n_same"
  fi
  if [ "$n_bad" -gt 0 ]; then
    printf '  • Entradas inválidas ignoradas no tema: %s\n' "$n_bad"
  fi
  printf '\n'
  printf 'Verifique se as chaves do tema (%s) existem como linhas ativas\n' "$THEME_FILE"
  printf 'nas seções [color]/[colors-dark]/[colors-light] do foot.ini.\n'
fi
