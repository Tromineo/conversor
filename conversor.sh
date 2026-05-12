#!/bin/bash

<<<<<<< Updated upstream
PIPER_MODELS_DIR="${HOME}/.local/share/piper"

=======
## Arquivo de log
LOG_FILE="$(dirname "$0")/conversor.log"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE"
}

## Verifica se a chave da API do Google foi definida
if [ -z "$GOOGLE_API_KEY" ]; then
  log "ERRO: variável GOOGLE_API_KEY não definida."
  log "Defina via variável de ambiente ou crie o arquivo .env com GOOGLE_API_KEY=sua_chave"
  exit 1
fi
## Se o primeiro parametro for vazio, exibe a ajuda
>>>>>>> Stashed changes
if [ -z "$1" ]; then
  echo "Uso: $0 <URL> [EN|BR]"
  echo ""
  echo "  EN  ->  en_US-lessac-medium"
  echo "  BR  ->  pt_BR-faber-medium (padrão)"
  exit 1
fi

URL="$1"

TIMESTAMP=$(date +%s)
DOMAIN=$(echo "$URL" | awk -F/ '{print $3}')

TMP_HTML="/tmp/page_$TIMESTAMP.html"
OUTPUT_TEXT="${DOMAIN}_$TIMESTAMP.txt"
OUTPUT_AUDIO="${DOMAIN}_$TIMESTAMP.wav"
case "${2^^}" in
  EN) PIPER_MODEL_NAME="en_US-lessac-medium" ;;
  BR|*) PIPER_MODEL_NAME="pt_BR-faber-medium" ;;
esac
<<<<<<< Updated upstream
PIPER_MODEL="${PIPER_MODELS_DIR}/${PIPER_MODEL_NAME}.onnx"

if [ ! -f "$PIPER_MODEL" ]; then
  echo "Erro: modelo '$PIPER_MODEL_NAME' não encontrado em $PIPER_MODELS_DIR"
  exit 1
fi

echo "Baixando conteúdo da URL..."
=======
## Faz o download do conteúdo da URL e salva em um arquivo temporário
log "Iniciando conversão: URL=$URL IDIOMA=${2^^:-BR}"
log "Baixando conteúdo da URL..."
>>>>>>> Stashed changes
curl -s "$URL" -o "$TMP_HTML"

if [ ! -s "$TMP_HTML" ]; then
  log "ERRO: falha ao baixar conteúdo da URL"
  exit 1
fi

<<<<<<< Updated upstream
echo "Extraindo texto do HTML..."
lynx -dump -nolist "$TMP_HTML" > "$OUTPUT_TEXT"
=======
log "Extraindo texto do HTML..."
lynx -dump -nolist "$TMP_HTML" \
  | grep -vE '^\s*(https?://|www\.)\S+$' \
  | sed \
      -e 's|https\?://[^[:space:]]*||g' \
      -e 's/^[[:space:]]*[*•·–—-][[:space:]]*//' \
      -e 's/\[[0-9]*\]//g' \
      -e 's/[#@|<>{}\\^~`_]//g' \
      -e 's/\([0-9]\)%/\1 por cento/g' \
      -e 's/ \& / e /g' \
      -e 's/C++/C plus plus/g' \
      -e 's/\.NET/ponto NET/g' \
      -e 's/\bAI\b/Inteligência Artificial/g' \
      -e 's/\bML\b/Machine Learning/g' \
      -e 's/\bAPI\b/A P I/g' \
      -e 's/\bDr\./Doutor/g' \
      -e 's/\bSr\./Senhor/g' \
      -e 's/\bSra\./Senhora/g' \
      -e 's/\betc\./etcétera/g' \
      -e 's/\bex\./por exemplo/g' \
      -e 's/\bi\.e\./ou seja/g' \
      -e 's/\be\.g\./por exemplo/g' \
      -e 's/\([a-záéíóúãõâêôçA-Z]\)$/\1./' \
  | awk '
      BEGIN {
          # Heurística: poucas palavras + palavras genéricas de navegação/UI = remove
          split("home about menu subscribe signin login register contact share follow tags search categories newsletter youtube twitter facebook instagram linkedin feed activity comments copyright privacy cookie button avatar rss archive author tag category next prev previous sobre inicio categorias assinar entrar cadastrar contato compartilhar seguir buscar pagina proximo anterior mim", gw, " ")
          for (i in gw) generic[gw[i]] = 1
      }
      # Remove linhas com padrões de botão/UI
      /\(BUTTON\)/ { next }
      # Converte CAPS para minúsculas
      /^[[:upper:][:space:]]{10,}$/ { print tolower($0); next }
      # Remove linhas muito curtas (exceto linhas em branco)
      length($0) <= 5 && !/^[[:space:]]*$/ { next }
      {
          # Heurística: ≤ 6 palavras E ≥ 1 palavra genérica → navegação/UI → remove
          nw = split($0, words, /[[:space:]]+/)
          wc = 0; gc = 0
          for (i = 1; i <= nw; i++) {
              w = words[i]
              gsub(/[^[:alpha:]]/, "", w)
              if (length(w) == 0) continue
              wc++
              if (generic[tolower(w)]) gc++
          }
          if (wc > 0 && wc <= 6 && gc >= 1) next
          print
      }
    ' \
  | sed 's/^[[:space:]]*//' \
  | grep -vE '^([A-ZÁÉÍÓÚ][a-záéíóú]+[[:space:]]*){1,3}$' \
  | awk 'NF==0 || !seen[$0]++' \
  | cat -s \
  > "$OUTPUT_TEXT"
>>>>>>> Stashed changes

if [ ! -s "$OUTPUT_TEXT" ]; then
  log "ERRO: falha ao extrair texto do HTML"
  exit 1
fi

log "Texto salvo em: $OUTPUT_TEXT"

log "Convertendo texto em áudio ($TOTAL_CHUNKS chunks)..."

TOTAL_LINES=$(wc -l < "$OUTPUT_TEXT")
[ "$TOTAL_LINES" -eq 0 ] && TOTAL_LINES=1
CHUNK_LINES=50
CHUNK_DIR=$(mktemp -d)

split -l "$CHUNK_LINES" "$OUTPUT_TEXT" "${CHUNK_DIR}/chunk_"

CHUNK_FILES=("${CHUNK_DIR}"/chunk_*)
TOTAL_CHUNKS=${#CHUNK_FILES[@]}
CHUNK_WAVS=()
PROCESSED=0

for chunk in "${CHUNK_FILES[@]}"; do
  chunk_wav="${chunk}.wav"
  piper --model "$PIPER_MODEL" --output_file "$chunk_wav" < "$chunk" 2>/dev/null
  if [ $? -ne 0 ]; then
    printf "\n"
<<<<<<< Updated upstream
    echo "Erro ao gerar áudio"
=======
    log "ERRO: falha ao gerar áudio no chunk $PROCESSED. Resposta: $(echo "$RESPONSE" | jq -c '.' 2>/dev/null || echo "$RESPONSE")"
    rm -rf "$CHUNK_DIR"
    exit 1
  fi
  echo "$AUDIO_CONTENT" | base64 -d > "$chunk_wav"
  if [ ! -s "$chunk_wav" ]; then
    printf "\n"
    log "ERRO: falha ao decodificar áudio do chunk $PROCESSED"
>>>>>>> Stashed changes
    rm -rf "$CHUNK_DIR"
    exit 1
  fi
  CHUNK_WAVS+=("$chunk_wav")
  PROCESSED=$((PROCESSED + 1))
  PERCENT=$(( PROCESSED * 100 / TOTAL_CHUNKS ))
  FILLED=$(( PERCENT / 2 ))
  BAR=""
  for ((k=0; k<50; k++)); do
    if (( k < FILLED )); then BAR+="="; else BAR+="-"; fi
  done
  printf "\r  Processando: [%s] %3d%%" "$BAR" "$PERCENT"
done

printf "\n"

sox "${CHUNK_WAVS[@]}" "$OUTPUT_AUDIO" 2>/dev/null
rm -rf "$CHUNK_DIR"

if [ ! -f "$OUTPUT_AUDIO" ]; then
  log "ERRO: falha ao gerar o arquivo de áudio final"
  exit 1
fi

log "Processo concluído!"
log "Arquivo de texto: $(pwd)/$OUTPUT_TEXT"
log "Arquivo de áudio: $(pwd)/$OUTPUT_AUDIO"