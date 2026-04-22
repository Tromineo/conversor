#!/bin/bash

# Validação básica
if [ -z "$1" ]; then
  echo "Uso: $0 <URL>"
  exit 1
fi

URL="$1"

TIMESTAMP=$(date +%s)
DOMAIN=$(echo "$URL" | awk -F/ '{print $3}')

TMP_HTML="/tmp/page_$TIMESTAMP.html"
OUTPUT_TEXT="${DOMAIN}_$TIMESTAMP.txt"
OUTPUT_AUDIO="${DOMAIN}_$TIMESTAMP.mp3"

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
gtts-cli -f "$OUTPUT_TEXT" --output "$OUTPUT_AUDIO"

if [ ! -f "$OUTPUT_AUDIO" ]; then
  echo "Erro ao gerar áudio"
  exit 1
fi

echo "Processo concluído!"
echo "Arquivo de texto: $(pwd)/$OUTPUT_TEXT"
echo "Arquivo de áudio: $(pwd)/$OUTPUT_AUDIO"