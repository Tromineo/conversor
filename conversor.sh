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
  ## Remove linhas que são apenas URLs
  grep -vE '^\s*(https?://|www\.)\S+$' | \
  ## Remove URLs no meio de linhas
  sed 's|https\?://[^[:space:]]*||g' | \
  ## Remove marcadores de lista
  sed 's/^[[:space:]]*[*•·–—-][[:space:]]*//' | \
  ## Remove referências numéricas tipo [1], [42]
  sed 's/\[[0-9]*\]//g' | \
  ## Remove símbolos problemáticos
  sed 's/[#@|<>{}\\^~`_]//g' | \
  ## Substitui % por " por cento"
  sed 's/\([0-9]\)%/\1 por cento/g' | \
  ## Substitui & por " e "
  sed 's/ & / e /g' | \
  ## Trata siglas técnicas comuns
  sed 's/C++/C plus plus/g' | \
  sed 's/\.NET/ponto NET/g' | \
  sed 's/\bAI\b/Inteligência Artificial/g' | \
  sed 's/\bML\b/Machine Learning/g' | \
  sed 's/\bAPI\b/A P I/g' | \
  ## Expande abreviações comuns
  sed 's/\bDr\./Doutor/g' | \
  sed 's/\bSr\./Senhor/g' | \
  sed 's/\bSra\./Senhora/g' | \
  sed 's/\betc\./etcétera/g' | \
  sed 's/\bex\./por exemplo/g' | \
  sed 's/\bi\.e\./ou seja/g' | \
  sed 's/\be\.g\./por exemplo/g' | \
  ## Garante ponto final em linhas que terminam com letra (facilita pausa natural)
  sed 's/\([a-záéíóúãõâêôçA-Z]\)$/\1./' | \
  ## Converte linhas totalmente em CAPS para minúsculas
  awk '{if ($0 ~ /^[[:upper:][:space:]]{10,}$/) print tolower($0); else print}' | \
  ## Remove linhas muito curtas (menus, botões, rótulos)
  awk 'length($0) > 5 || $0 ~ /^[[:space:]]*$/' | \
  ## Remove linhas que parecem cabeçalhos de navegação (só palavras isoladas em maiúscula)
  grep -vE '^[[:space:]]*([A-ZÁÉÍÓÚ][a-záéíóú]+[[:space:]]*){1,3}$' | \
  ## Colapsa múltiplas linhas em branco em uma só
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