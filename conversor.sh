#!/bin/bash

PIPER_MODELS_DIR="${HOME}/.local/share/piper"

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
PIPER_MODEL="${PIPER_MODELS_DIR}/${PIPER_MODEL_NAME}.onnx"

if [ ! -f "$PIPER_MODEL" ]; then
  echo "Erro: modelo '$PIPER_MODEL_NAME' não encontrado em $PIPER_MODELS_DIR"
  exit 1
fi

echo "Baixando conteúdo da URL..."
curl -s "$URL" -o "$TMP_HTML"

if [ ! -s "$TMP_HTML" ]; then
  echo "Erro ao baixar conteúdo"
  exit 1
fi

echo "Extraindo texto do HTML..."
lynx -dump -nolist "$TMP_HTML" > "$OUTPUT_TEXT"

if [ ! -s "$OUTPUT_TEXT" ]; then
  echo "Erro ao extrair texto"
  exit 1
fi

echo "Texto salvo em: $OUTPUT_TEXT"

echo "Convertendo texto em áudio..."
cat "$OUTPUT_TEXT" | piper --model "$PIPER_MODEL" --output_file "$OUTPUT_AUDIO" &
PIPER_PID=$!

ELAPSED=0

while kill -0 "$PIPER_PID" 2>/dev/null; do
  sleep 30
  ELAPSED=$((ELAPSED + 30))
  if kill -0 "$PIPER_PID" 2>/dev/null; then
    echo "Arquivo ainda sendo processado... (${ELAPSED}s)"
  fi
done

wait "$PIPER_PID"
PIPER_EXIT=$?

if [ "$PIPER_EXIT" -ne 0 ] || [ ! -f "$OUTPUT_AUDIO" ]; then
  echo "Erro ao gerar áudio"
  exit 1
fi

echo "Processo concluído!"
echo "Arquivo de texto: $(pwd)/$OUTPUT_TEXT"
echo "Arquivo de áudio: $(pwd)/$OUTPUT_AUDIO"