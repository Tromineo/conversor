# conversor.sh

Script Bash que baixa o conteúdo de uma URL, extrai o texto do HTML e converte para um arquivo de áudio WAV usando o [Piper TTS](https://github.com/rhasspy/piper) localmente, sem dependência de internet para a geração do áudio.

## Dependências

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

Certifique-se de que o script tem permissão de execução:

```bash
chmod +x conversor.sh
```

## Changelog

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
