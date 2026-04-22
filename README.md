# conversor.sh

Script Bash que baixa o conteúdo de uma URL, extrai o texto do HTML e converte para um arquivo de áudio MP3.

## Dependências

- **curl** — download do HTML
- **lynx** — extração de texto a partir do HTML
- **gtts-cli** — conversão de texto para fala (Google Text-to-Speech)

Instalação das dependências (Debian/Ubuntu):

```bash
sudo apt install curl lynx
pip install gTTS
```

## Uso

```bash
./conversor.sh <URL>
```

### Exemplo

```bash
./conversor.sh https://exemplo.com/artigo
```

## Saída

O script gera dois arquivos no diretório atual, com o domínio e um timestamp no nome:

| Arquivo | Descrição |
|---|---|
| `<dominio>_<timestamp>.txt` | Texto extraído da página |
| `<dominio>_<timestamp>.mp3` | Áudio gerado a partir do texto |

## Fluxo de execução

1. Recebe a URL como argumento
2. Faz download do HTML com `curl`
3. Extrai o texto legível com `lynx`
4. Converte o texto em áudio MP3 com `gtts-cli`

## Tratamento de erros

O script valida cada etapa e encerra com mensagem de erro caso:
- Nenhum argumento seja fornecido
- O download do HTML falhe ou retorne vazio
- A extração de texto gere arquivo vazio
- O arquivo de áudio não seja criado

## Permissões

Certifique-se de que o script tem permissão de execução:

```bash
chmod +x conversor.sh
```

## Changelog

### v1.0.0
- Download de HTML via `curl`
- Extração de texto com `lynx`
- Geração de áudio MP3 com `gtts-cli`
- Validação de entradas e saídas em cada etapa
- Nome dos arquivos de saída baseado em domínio + timestamp
