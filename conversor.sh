#!/bin/bash
## Define o diretório onde os modelos do Piper estão armazenados
PIPER_MODELS_DIR="${HOME}/.local/share/piper"
## Se o primeiro parametro for vazio, exibe a ajuda
if [ -z "$1" ]; then
  echo "Uso: $0 <URL> [EN|BR]"
  echo ""
  echo "  EN  ->  en_US-lessac-medium"
  echo "  BR  ->  pt_BR-faber-medium (padrão)"
  exit 1
fi

URL="$1"
## Gerar timestamp para criar arquivos únicos
TIMESTAMP=$(date +%s)
## Extrai o domínio da URL
DOMAIN=$(echo "$URL" | awk -F/ '{print $3}')
## Define o caminho dos arquivos de saída
TMP_HTML="/tmp/page_$TIMESTAMP.html"

OUTPUT_TEXT="${DOMAIN}_$TIMESTAMP.txt"
OUTPUT_AUDIO="${DOMAIN}_$TIMESTAMP.wav"
## Seleciona o modelo do Piper com base no segundo parâmetro (idioma)
case "${2^^}" in
  EN) PIPER_MODEL_NAME="en_US-lessac-medium" ;;
  BR|*) PIPER_MODEL_NAME="pt_BR-faber-medium" ;;
esac
PIPER_MODEL="${PIPER_MODELS_DIR}/${PIPER_MODEL_NAME}.onnx"
## Verifica se o modelo do Piper existe
if [ ! -f "$PIPER_MODEL" ]; then
  echo "Erro: modelo '$PIPER_MODEL_NAME' não encontrado em $PIPER_MODELS_DIR"
  exit 1
fi
## Faz o download do conteúdo da URL e salva em um arquivo temporário
echo "Baixando conteúdo da URL..."
curl -s "$URL" -o "$TMP_HTML"

if [ ! -s "$TMP_HTML" ]; then
  echo "Erro ao baixar conteúdo"
  exit 1
fi

echo "Extraindo texto do HTML..."
lynx -dump -nolist "$TMP_HTML" | \
  grep -vE '^\s*(https?://|www\.)\S+' | \
  sed 's/^[[:space:]]*[*•·–—-][[:space:]]*//' | \
  sed 's/\[[0-9]*\]//g' | \
  sed 's/[#@|<>{}\\^~`]//g' | \
  sed 's/%/ por cento/g' | \
  sed 's/&/ e /g' | \
  sed 's/C++/C plus plus/g' | \
  awk '{if ($0 ~ /^[[:upper:] ]{10,}$/) print tolower($0); else print}' | \
  awk 'length($0) > 5 || $0 ~ /^[[:space:]]*$/' | \
  cat -s \
  > "$OUTPUT_TEXT"

if [ ! -s "$OUTPUT_TEXT" ]; then
  echo "Erro ao extrair texto"
  exit 1
fi

echo "Texto salvo em: $OUTPUT_TEXT"

echo "Convertendo texto em áudio..."

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
    echo "Erro ao gerar áudio"
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
  echo "Erro ao gerar áudio"
  exit 1
fi

echo "Processo concluído!"
echo "Arquivo de texto: $(pwd)/$OUTPUT_TEXT"
echo "Arquivo de áudio: $(pwd)/$OUTPUT_AUDIO"