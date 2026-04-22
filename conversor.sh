#!/bin/bash

if [ -z "$1" ]; then
  echo "Uso: $0 <URL>"
  exit 1
fi

URL="$1"

TIMESTAMP=$(date +%s)
DOMAIN=$(echo "$URL" | awk -F/ '{print $3}')

TMP_HTML="/tmp/page_$TIMESTAMP.html"
OUTPUT_TEXT="${DOMAIN}_$TIMESTAMP.txt"
OUTPUT_AUDIO="${DOMAIN}_$TIMESTAMP.wav"
PIPER_MODEL="${HOME}/.local/share/piper/pt_BR-faber-medium.onnx"

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