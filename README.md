# conversor.sh

Script Bash que baixa o conteúdo de uma URL, extrai o texto do HTML e converte para um arquivo de áudio WAV usando o [Piper TTS](https://github.com/rhasspy/piper) localmente, sem dependência de internet para a geração do áudio.

## Scripts

| Script | Descrição |
|---|---|
| `conversor.sh` | URL → texto → WAV usando **Piper TTS** (local) |
| `voz.sh` | Texto → WAV usando **ChatTTS** via **Docker** |

---

## conversor.sh

### Dependências

- **curl** — download do HTML
- **lynx** — extração de texto a partir do HTML
- **piper** — conversão de texto para fala (TTS local)
- **sox** — concatenação dos arquivos WAV gerados por chunk

Instalação das dependências (Debian/Ubuntu):

```bash
sudo apt install curl lynx sox
pip install piper-tts
```

### Modelos de voz

Os modelos devem estar em `~/.local/share/piper/`. Cada modelo requer dois arquivos: `.onnx` e `.onnx.json`.

**Português brasileiro (BR):**
```bash
mkdir -p ~/.local/share/piper
wget -P ~/.local/share/piper \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx
wget -P ~/.local/share/piper \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx.json
```

**Inglês americano (EN):**
```bash
wget -P ~/.local/share/piper \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx
wget -P ~/.local/share/piper \
  https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json
```

## Uso

```bash
./conversor.sh <URL> [EN|BR]
```

O segundo parâmetro é opcional. Se omitido, o modelo `BR` é usado por padrão.

| Parâmetro | Modelo utilizado |
|---|---|
| `BR` (padrão) | `pt_BR-faber-medium` |
| `EN` | `en_US-lessac-medium` |

### Exemplos

```bash
# Português brasileiro (padrão)
./conversor.sh https://exemplo.com/artigo

# Português brasileiro (explícito)
./conversor.sh https://exemplo.com/artigo BR

# Inglês americano
./conversor.sh https://exemplo.com/artigo EN
```

## Saída

O script gera dois arquivos no diretório atual, com o domínio e um timestamp no nome:

| Arquivo | Descrição |
|---|---|
| `<dominio>_<timestamp>.txt` | Texto extraído da página |
| `<dominio>_<timestamp>.wav` | Áudio gerado a partir do texto |

## Fluxo de execução

1. Recebe a URL e opcionalmente o idioma do modelo (`EN` ou `BR`)
2. Valida o modelo selecionado em `~/.local/share/piper/`
3. Faz download do HTML com `curl`
4. Extrai o texto legível com `lynx`
5. Converte o texto em áudio WAV com `piper` em background
6. Exibe mensagens de progresso a cada 30 segundos enquanto a conversão estiver em andamento

## Tratamento de erros

O script valida cada etapa e encerra com mensagem de erro caso:
- Nenhuma URL seja fornecida
- O modelo de voz selecionado não seja encontrado em `~/.local/share/piper/`
- O download do HTML falhe ou retorne vazio
- A extração de texto gere arquivo vazio
- O arquivo de áudio não seja criado

## Permissões

```bash
chmod +x conversor.sh voz.sh
```

---

## voz.sh — ChatTTS via Docker

Síntese de fala de alta qualidade usando o modelo [ChatTTS](https://github.com/2noise/ChatTTS) executado dentro de um container Docker. Elimina a necessidade de instalação local de dependências pesadas (PyTorch, CUDA etc).

> **Idiomas suportados pelo ChatTTS:** inglês e chinês.

### Dependências

- **docker** — único requisito no host

### Primeiro uso

Na primeira execução o script constrói a imagem Docker e baixa os modelos do HuggingFace (~700 MB). Isso acontece automaticamente.

```bash
# Construção manual (opcional)
./voz.sh build
```

### Síntese com voz aleatória

```bash
./voz.sh gerar "Your text here"
./voz.sh gerar "Your text here" output.wav
./voz.sh gerar -f texto.txt output.wav
```

### Clonagem de voz a partir de áudio

Passa um arquivo de áudio (WAV, MP3, FLAC…) como referência. O ChatTTS extrai o embedding do locutor usando o DVAE encoder interno e sintetiza o texto com aquela identidade de voz.

```bash
# Clona a voz de ref.wav e sintetiza o texto
./voz.sh clonar ref.wav "Hello world"
./voz.sh clonar ref.wav "Hello world" saida.wav

# Clona a voz e usa um arquivo de texto
./voz.sh clonar ref.wav -f texto.txt
./voz.sh clonar ref.wav -f texto.txt saida.wav
```

### Salvar e reutilizar perfis de voz

```bash
# Salva um perfil aleatório
./voz.sh salvar-voz narrador

# Extrai e salva o perfil de voz de um áudio de referência
./voz.sh salvar-voz narrador voz_referencia.wav

# Usa o perfil salvo ao gerar
./voz.sh gerar "Hello world" saida.wav narrador

# Lista todos os perfis
./voz.sh listar

# Remove um perfil
./voz.sh remover narrador
```

Os perfis são embeddings de locutor salvos como JSON. Podem ser gerados de duas formas:
- **Aleatório** — amostra do espaço latente do modelo
- **A partir de áudio** — extração via DVAE encoder do ChatTTS a partir de qualquer áudio de referência

Os perfis ficam em `~/.local/share/conversor/vozes/`.  
Os modelos são cacheados em `~/.cache/chattts/models/`.

### Volumes Docker

| Volume no container | Mapeamento no host |
|---|---|
| `/output` | `$PWD` — diretório atual (saída do áudio) |
| `/models` | `~/.cache/chattts/models` — cache dos modelos HuggingFace |
| `/vozes` | `~/.local/share/conversor/vozes` — perfis de locutor |

### GPU NVIDIA (opcional)

Para usar a GPU, edite `Dockerfile.chattts` e substitua a linha de instalação do PyTorch:

```dockerfile
# Trocar:
RUN pip install --no-cache-dir torch torchaudio --index-url https://download.pytorch.org/whl/cpu
# Por (CUDA 12.1):
RUN pip install --no-cache-dir torch torchaudio --index-url https://download.pytorch.org/whl/cu121
```

E adicione `--gpus all` ao `docker run` em `voz.sh`.

---

## Changelog

### v3.0.0
- `voz.sh` reescrito: substituição de Coqui TTS (XTTS v2 local) por **ChatTTS via Docker**
- Adicionado `Dockerfile.chattts` e `tts_entrypoint.py`
- Novo comando `clonar` para síntese com voz extraída de um áudio de referência
- `salvar-voz` aceita áudio de referência para extração do perfil de voz via DVAE
- Perfis de voz agora são strings codificadas pelo ChatTTS (formato JSON)
- Correção no save/load do embedding (era tensor, agora é string nativa do ChatTTS)

### v2.0.0
- Substituição do `gtts-cli` pelo `piper` (TTS local, sem internet)
- Saída alterada de MP3 para WAV
- Adicionado segundo parâmetro `[EN|BR]` para seleção do modelo de voz
- Adicionado monitoramento de progresso a cada 30 segundos durante a conversão

### v1.0.0
- Download de HTML via `curl`
- Extração de texto com `lynx`
- Geração de áudio MP3 com `gtts-cli`
- Validação de entradas e saídas em cada etapa
- Nome dos arquivos de saída baseado em domínio + timestamp
