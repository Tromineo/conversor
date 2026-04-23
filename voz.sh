#!/bin/bash
# voz.sh — Síntese de fala com ChatTTS via Docker
#
# Dependências: docker
# Idiomas suportados pelo ChatTTS: inglês, chinês
# Os modelos (~700 MB) são baixados automaticamente na primeira execução
# e ficam em cache no diretório $MODELOS_DIR.

IMAGE_NAME="chattts-local"
VOZES_DIR="${HOME}/.local/share/conversor/vozes"
MODELOS_DIR="${HOME}/.cache/chattts/models"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$VOZES_DIR" "$MODELOS_DIR"

COMANDO="${1:-}"

show_uso() {
  echo "Uso: $(basename "$0") <comando> [opções]"
  echo ""
  echo "Comandos:"
  echo "  build                                        Constrói a imagem Docker do ChatTTS"
  echo ""
  echo "  gerar <\"texto\"> [saida.wav] [perfil]        Gera áudio a partir do texto"
  echo "  gerar -f <arquivo> [saida.wav] [perfil]      Gera áudio a partir de arquivo de texto"
  echo ""
  echo "  salvar-voz <nome>                            Amostra e salva um perfil de voz aleatório"
  echo "  salvar-voz <nome> <audio-ref>                Extrai e salva o perfil de voz do áudio"
  echo ""
  echo "  clonar <audio-ref> <\"texto\"> [saida.wav]    Clona a voz do áudio e sintetiza o texto"
  echo "  clonar <audio-ref> -f <arquivo> [saida.wav]  Clona a voz usando arquivo de texto"
  echo ""
  echo "  listar                                       Lista os perfis de voz salvos"
  echo "  remover <nome>                               Remove um perfil de voz"
  echo ""
  echo "Nota: ChatTTS suporta inglês e chinês."
  echo "      Modelos ficam em:    $MODELOS_DIR"
  echo "      Perfis de voz em:    $VOZES_DIR"
}

build_image() {
  echo "Construindo imagem Docker do ChatTTS..."
  echo "(isso pode levar alguns minutos na primeira vez)"
  docker build \
    -f "${SCRIPT_DIR}/Dockerfile.chattts" \
    -t "$IMAGE_NAME" \
    "${SCRIPT_DIR}"
  if [ $? -eq 0 ]; then
    echo "Imagem '${IMAGE_NAME}' criada com sucesso!"
  else
    echo "Erro ao construir a imagem Docker"
    exit 1
  fi
}

check_image() {
  if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "Imagem Docker '${IMAGE_NAME}' não encontrada. Construindo..."
    build_image
  fi
}

# Monta o áudio de referência e retorna os args de volume + caminho interno
# Uso: ref_audio_args=($(mount_ref_audio "/path/to/file.wav"))
# Retorna dois valores: a opção -v e o caminho interno /ref/<basename>
_ref_audio_docker_args() {
  local REF_REAL
  REF_REAL="$(realpath "$1")"
  local REF_DIR
  REF_DIR="$(dirname "$REF_REAL")"
  local REF_BASE
  REF_BASE="$(basename "$REF_REAL")"
  echo "-v" "${REF_DIR}:/ref:ro" "--ref-audio" "/ref/${REF_BASE}"
}

# Executa o container com mounts padrão
_run() {
  docker run --rm \
    -v "${PWD}:/output" \
    -v "${MODELOS_DIR}:/models" \
    -v "${VOZES_DIR}:/vozes" \
    "$IMAGE_NAME" "$@"
}

case "$COMANDO" in

  build)
    build_image
    ;;

  gerar)
    check_image

    if [ "$2" = "-f" ]; then
      ARQUIVO_TEXTO="$3"
      OUTPUT="${4:-saida_$(date +%s).wav}"
      SPK_NOME="${5:-}"

      if [ -z "$ARQUIVO_TEXTO" ] || [ ! -f "$ARQUIVO_TEXTO" ]; then
        echo "Erro: arquivo de texto não encontrado: ${3}"
        echo "Uso: $(basename "$0") gerar -f <arquivo> [saida.wav] [perfil]"
        exit 1
      fi

      ARQUIVO_REAL="$(realpath "$ARQUIVO_TEXTO")"
      ARQUIVO_DIR="$(dirname "$ARQUIVO_REAL")"
      ARQUIVO_BASE="$(basename "$ARQUIVO_REAL")"

      SPK_ARGS=()
      [ -n "$SPK_NOME" ] && SPK_ARGS+=("--spk" "/vozes/${SPK_NOME}.json")

      echo "Gerando áudio a partir do arquivo: $ARQUIVO_BASE"
      docker run --rm \
        -v "${PWD}:/output" \
        -v "${MODELOS_DIR}:/models" \
        -v "${VOZES_DIR}:/vozes" \
        -v "${ARQUIVO_DIR}:/input:ro" \
        "$IMAGE_NAME" \
          --file "/input/${ARQUIVO_BASE}" \
          --output "/output/${OUTPUT}" \
          "${SPK_ARGS[@]}"

    else
      TEXTO="$2"
      OUTPUT="${3:-saida_$(date +%s).wav}"
      SPK_NOME="${4:-}"

      if [ -z "$TEXTO" ]; then
        echo "Erro: informe o texto a ser sintetizado"
        echo "Uso: $(basename "$0") gerar <\"texto\"> [saida.wav] [perfil]"
        exit 1
      fi

      SPK_ARGS=()
      [ -n "$SPK_NOME" ] && SPK_ARGS+=("--spk" "/vozes/${SPK_NOME}.json")

      echo "Gerando áudio..."
      _run \
        --text "$TEXTO" \
        --output "/output/${OUTPUT}" \
        "${SPK_ARGS[@]}"
    fi

    if [ $? -eq 0 ] && [ -f "${PWD}/${OUTPUT}" ]; then
      echo "Arquivo gerado: $(pwd)/${OUTPUT}"
    fi
    ;;

  clonar)
    AUDIO_REF="$2"
    check_image

    if [ -z "$AUDIO_REF" ] || [ ! -f "$AUDIO_REF" ]; then
      echo "Erro: áudio de referência não encontrado: ${2}"
      echo "Uso: $(basename "$0") clonar <audio-ref> <\"texto\"> [saida.wav]"
      echo "     $(basename "$0") clonar <audio-ref> -f <arquivo> [saida.wav]"
      exit 1
    fi

    REF_REAL="$(realpath "$AUDIO_REF")"
    REF_DIR="$(dirname "$REF_REAL")"
    REF_BASE="$(basename "$REF_REAL")"

    if [ "$3" = "-f" ]; then
      ARQUIVO_TEXTO="$4"
      OUTPUT="${5:-clonado_$(date +%s).wav}"

      if [ -z "$ARQUIVO_TEXTO" ] || [ ! -f "$ARQUIVO_TEXTO" ]; then
        echo "Erro: arquivo de texto não encontrado: ${4}"
        exit 1
      fi

      ARQ_REAL="$(realpath "$ARQUIVO_TEXTO")"
      ARQ_DIR="$(dirname "$ARQ_REAL")"
      ARQ_BASE="$(basename "$ARQ_REAL")"

      echo "Clonando voz de '${REF_BASE}' a partir de arquivo de texto..."
      docker run --rm \
        -v "${PWD}:/output" \
        -v "${MODELOS_DIR}:/models" \
        -v "${VOZES_DIR}:/vozes" \
        -v "${REF_DIR}:/ref:ro" \
        -v "${ARQ_DIR}:/input:ro" \
        "$IMAGE_NAME" \
          --ref-audio "/ref/${REF_BASE}" \
          --file "/input/${ARQ_BASE}" \
          --output "/output/${OUTPUT}"

    else
      TEXTO="$3"
      OUTPUT="${4:-clonado_$(date +%s).wav}"

      if [ -z "$TEXTO" ]; then
        echo "Erro: informe o texto a ser sintetizado"
        echo "Uso: $(basename "$0") clonar <audio-ref> <\"texto\"> [saida.wav]"
        exit 1
      fi

      echo "Clonando voz de '${REF_BASE}'..."
      docker run --rm \
        -v "${PWD}:/output" \
        -v "${MODELOS_DIR}:/models" \
        -v "${VOZES_DIR}:/vozes" \
        -v "${REF_DIR}:/ref:ro" \
        "$IMAGE_NAME" \
          --ref-audio "/ref/${REF_BASE}" \
          --text "$TEXTO" \
          --output "/output/${OUTPUT}"
    fi

    if [ $? -eq 0 ] && [ -f "${PWD}/${OUTPUT}" ]; then
      echo "Arquivo gerado: $(pwd)/${OUTPUT}"
    fi
    ;;

  salvar-voz)
    NOME="$2"
    AUDIO_REF="${3:-}"

    if [ -z "$NOME" ]; then
      echo "Erro: informe um nome para o perfil de voz"
      echo "Uso: $(basename "$0") salvar-voz <nome> [audio-ref]"
      exit 1
    fi

    check_image

    if [ -n "$AUDIO_REF" ]; then
      if [ ! -f "$AUDIO_REF" ]; then
        echo "Erro: áudio de referência não encontrado: ${AUDIO_REF}"
        exit 1
      fi

      REF_REAL="$(realpath "$AUDIO_REF")"
      REF_DIR="$(dirname "$REF_REAL")"
      REF_BASE="$(basename "$REF_REAL")"

      echo "Extraindo perfil de voz de '${REF_BASE}' e salvando como '${NOME}'..."
      docker run --rm \
        -v "${MODELOS_DIR}:/models" \
        -v "${VOZES_DIR}:/vozes" \
        -v "${REF_DIR}:/ref:ro" \
        "$IMAGE_NAME" \
          --sample-only \
          --ref-audio "/ref/${REF_BASE}" \
          --export-spk "/vozes/${NOME}.json"

    else
      echo "Amostrando e salvando perfil de voz aleatório '${NOME}'..."
      docker run --rm \
        -v "${MODELOS_DIR}:/models" \
        -v "${VOZES_DIR}:/vozes" \
        "$IMAGE_NAME" \
          --sample-only \
          --export-spk "/vozes/${NOME}.json"
    fi

    if [ -f "${VOZES_DIR}/${NOME}.json" ]; then
      echo "Perfil '${NOME}' salvo em: ${VOZES_DIR}/${NOME}.json"
    else
      echo "Erro ao salvar o perfil de voz"
      exit 1
    fi
    ;;

  listar)
    echo "Perfis de voz salvos:"
    FOUND=0
    for f in "${VOZES_DIR}"/*.json; do
      [ -f "$f" ] || continue
      nome=$(basename "$f" .json)
      echo "  - ${nome}"
      FOUND=1
    done
    [ "$FOUND" -eq 0 ] && echo "  Nenhum perfil salvo"
    ;;

  remover)
    NOME="$2"

    if [ -z "$NOME" ]; then
      echo "Erro: informe o nome do perfil"
      echo "Uso: $(basename "$0") remover <nome>"
      exit 1
    fi

    ARQUIVO="${VOZES_DIR}/${NOME}.json"

    if [ ! -f "$ARQUIVO" ]; then
      echo "Erro: perfil '${NOME}' não encontrado"
      echo ""
      echo "Perfis disponíveis:"
      for f in "${VOZES_DIR}"/*.json; do
        [ -f "$f" ] && echo "  - $(basename "$f" .json)"
      done
      exit 1
    fi

    rm "$ARQUIVO"
    echo "Perfil '${NOME}' removido."
    ;;

  *)
    show_uso
    exit 1
    ;;

esac
