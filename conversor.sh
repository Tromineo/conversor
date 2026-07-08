#!/bin/bash

PIPER_MODELS_DIR="${HOME}/.local/share/piper"
LOG_FILE="/tmp/conversor_$(date +%s).log"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg"
  echo "$msg" >> "$LOG_FILE"
}

pos_processamento() {
  local arquivo="$1"

  # Remove separadores horizontais (linha com 5+ underscores)
  sed -i '/^[[:space:]]*_\{5,\}[[:space:]]*$/d' "$arquivo"

  # Remove linhas com menus de navegação (separados por │)
  sed -i '/│/d' "$arquivo"

  # Remove linhas com copyright (©)
  sed -i '/^[[:space:]]*©/d' "$arquivo"

  # Remove rótulos (BUTTON) gerados pelo lynx
  sed -i 's/[[:space:]]*(BUTTON)[^[:space:]]*//' "$arquivo"

  # Remove campos de formulário renderizados pelo lynx (5+ underscores)
  sed -i 's/__\{5,\}//' "$arquivo"

  # Remove marcadores de notas de rodapé (^1, ^2, ...)
  sed -i 's/\^[0-9]\+//g' "$arquivo"

  # Remove símbolo de retorno de rodapé (↩)
  sed -i 's/↩//g' "$arquivo"

  # Remove asteriscos e outros símbolos de ênfase em markdown
  sed -i 's/\*\*//g' "$arquivo"  # ** (markdown bold)
  sed -i 's/__//g' "$arquivo"    # __ (markdown bold alt)
  sed -i 's/\*//g' "$arquivo"    # * individual (bullet points, emphasis)

  # Remove símbolos especiais usando perl para melhor suporte a Unicode
  perl -i -pe 's/[«»]//g' "$arquivo"           # Aspas angulares
  perl -i -pe 's/[""„‟]//g' "$arquivo"         # Aspas tipográficas
  perl -i -pe 's/–/ /g' "$arquivo"             # Travessão (substitui por espaço)
  perl -i -pe 's/—/ /g' "$arquivo"             # Travessão longo
  perl -i -pe 's/[{}]//g' "$arquivo"           # Chaves vazias
  perl -i -pe 's/\[\]//g' "$arquivo"           # Colchetes vazios para checkboxes
  perl -i -pe 's/\[x\]//g' "$arquivo"          # Checkboxes marcados
  perl -i -pe 's/\[X\]//g' "$arquivo"          # Checkboxes marcados maiúsculos

  # Remove símbolos decorativos comuns
  perl -i -pe 's/✓//g' "$arquivo"              # Checkmark
  perl -i -pe 's/✗//g' "$arquivo"              # X mark
  perl -i -pe 's/→//g' "$arquivo"              # Seta
  perl -i -pe 's/←//g' "$arquivo"              # Seta reversa
  perl -i -pe 's/↓//g' "$arquivo"              # Seta para baixo
  perl -i -pe 's/↑//g' "$arquivo"              # Seta para cima
  perl -i -pe 's/•//g' "$arquivo"              # Bullet point
  perl -i -pe 's/°//g' "$arquivo"              # Grau

  # Remove parênteses vazios ou com apenas números
  perl -i -pe 's/\([0-9]+\)//g' "$arquivo"     # (1), (2), etc. (referências)
  perl -i -pe 's/\(\)//g' "$arquivo"           # Parênteses vazios

  # Remove símbolos matemáticos e monetários problemáticos
  perl -i -pe 's/†//g' "$arquivo"              # Obelisco
  perl -i -pe 's/‡//g' "$arquivo"              # Duplo obelisco
  perl -i -pe 's/¶//g' "$arquivo"              # Símbolo de parágrafo
  perl -i -pe 's/§//g' "$arquivo"              # Símbolo de seção
  perl -i -pe 's/™//g' "$arquivo"              # Trademark
  perl -i -pe 's/®//g' "$arquivo"              # Registered
  perl -i -pe 's/×//g' "$arquivo"              # Multiplicação
  perl -i -pe 's/↩//g' "$arquivo"              # Seta de retorno
  
  # Remove linhas inteiras de apenas símbolos ou vazias de conteúdo significativo
  sed -i '/^[^a-zA-Z0-9]*$/d' "$arquivo"       # Linhas com apenas símbolos/espaços
  
  # Remove linhas com padrões comuns de boilerplate e navegação
  sed -i '/[Cc]ontinue reading/d' "$arquivo"   # Continue reading...
  sed -i '/[Jj]ava[Ss]cript/d' "$arquivo"      # JavaScript required
  sed -i '/[Ss]ubstack/d' "$arquivo"           # Substack boilerplate
  sed -i '/[Rr]eady for more/d' "$arquivo"     # Ready for more?
  sed -i '/^[[:space:]]*No posts\.[[:space:]]*$/d' "$arquivo"  # No posts.
  sed -i '/RSS feed/d' "$arquivo"              # RSS feed headers
  sed -i '/[Cc]onsider subscrib/d' "$arquivo"  # Subscribe CTAs
  sed -i '/Privacy.*Terms/d' "$arquivo"        # Privacy · Terms footer
  sed -i "/[Hh]ere'*s.*preview/d" "$arquivo"   # Here's a preview...
  sed -i '/[Gg]et the app/d' "$arquivo"        # Get the app
  sed -i '/^[[:space:]]*Start your/d' "$arquivo"  # Start your...

  # Colapsa múltiplas linhas em branco consecutivas em uma única
  cat -s "$arquivo" > "${arquivo}.tmp" && mv "${arquivo}.tmp" "$arquivo"
}

if [ -z "$1" ]; then
  echo "Uso: $0 <URL|ARQUIVO> [EN|BR]"
  echo ""
  echo "  URL      -> Endereço HTTP/HTTPS para baixar e processar"
  echo "  ARQUIVO  -> Caminho para arquivo de texto local"
  echo ""
  echo "  EN  ->  en_US-lessac-medium"
  echo "  BR  ->  pt_BR-faber-medium (padrão)"
  exit 1
fi

INPUT="$1"
TIMESTAMP=$(date +%s)

# Detectar se é arquivo local ou URL
if [ -f "$INPUT" ]; then
  # É um arquivo local
  INPUT_TYPE="FILE"
  DOMAIN=$(basename "$INPUT" | sed 's/\.[^.]*$//')
else
  # Trata como URL
  INPUT_TYPE="URL"
  DOMAIN=$(echo "$INPUT" | awk -F/ '{print $3}')
fi

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

if [ "$INPUT_TYPE" = "FILE" ]; then
  echo "Lendo arquivo local..."
  if [ ! -s "$INPUT" ]; then
    log "ERRO: arquivo não encontrado ou vazio: $INPUT"
    exit 1
  fi
  # Copia o arquivo como texto de entrada
  cp "$INPUT" "$OUTPUT_TEXT"
else
  echo "Baixando conteúdo da URL..."
  curl -s "$INPUT" -o "$TMP_HTML"

  if [ ! -s "$TMP_HTML" ]; then
    log "ERRO: falha ao baixar conteúdo da URL"
    exit 1
  fi

  echo "Extraindo texto do HTML..."
  lynx -dump -nolist "$TMP_HTML" > "$OUTPUT_TEXT"
fi

if [ ! -s "$OUTPUT_TEXT" ]; then
  log "ERRO: falha ao processar o arquivo/HTML"
  exit 1
fi

log "Texto salvo em: $OUTPUT_TEXT"

# Limpar arquivo HTML temporário se foi criado
if [ "$INPUT_TYPE" = "URL" ] && [ -f "$TMP_HTML" ]; then
  rm -f "$TMP_HTML"
fi

log "Pós-processando texto..."
pos_processamento "$OUTPUT_TEXT"
log "Pós-processamento concluído."

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
  log "ERRO: falha ao gerar o arquivo de áudio final"
  exit 1
fi

log "Processo concluído!"
log "Arquivo de texto: $(pwd)/$OUTPUT_TEXT"
log "Arquivo de áudio: $(pwd)/$OUTPUT_AUDIO"