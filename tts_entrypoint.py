#!/usr/bin/env python3
"""
Entrypoint do container ChatTTS.
Converte texto em áudio usando o modelo ChatTTS.

Modos de uso:

  # Texto direto com voz aleatória
  --text "Hello world" --output /output/out.wav

  # A partir de arquivo de texto
  --file /input/texto.txt --output /output/out.wav

  # Clonar voz a partir de um áudio de referência
  --text "Hello world" --ref-audio /input/ref.wav --output /output/out.wav

  # Salvar perfil de voz aleatório
  --sample-only --export-spk /vozes/narrador.json

  # Extrair e salvar perfil de voz a partir de áudio de referência
  --sample-only --ref-audio /input/ref.wav --export-spk /vozes/narrador.json

  # Usar perfil de voz salvo previamente
  --text "Hello world" --spk /vozes/narrador.json --output /output/out.wav
"""

import sys
import os
import argparse
import json


def parse_args():
    parser = argparse.ArgumentParser(
        description="ChatTTS — síntese de fala a partir de texto"
    )

    input_group = parser.add_mutually_exclusive_group()
    input_group.add_argument("--text", "-t", help="Texto a sintetizar")
    input_group.add_argument("--file", "-f", help="Arquivo de texto a sintetizar")

    parser.add_argument(
        "--output", "-o",
        default="/output/audio.wav",
        help="Caminho do arquivo WAV de saída (padrão: /output/audio.wav)",
    )
    parser.add_argument(
        "--spk",
        help="Arquivo JSON com o perfil do locutor (gerado por --export-spk)",
    )
    parser.add_argument(
        "--ref-audio",
        metavar="AUDIO",
        help="Áudio de referência para clonagem de voz (WAV, MP3, FLAC…)",
    )
    parser.add_argument(
        "--export-spk",
        metavar="PATH",
        help="Salva o perfil do locutor neste arquivo JSON para reutilização",
    )
    parser.add_argument(
        "--sample-only",
        action="store_true",
        help="Apenas extrai/amostra o locutor e salva via --export-spk (não gera áudio)",
    )
    parser.add_argument(
        "--temperature", type=float, default=0.3,
        help="Temperatura de inferência (padrão: 0.3)",
    )
    parser.add_argument(
        "--oral", type=int, default=2, choices=range(10),
        help="Oralidade 0-9 (padrão: 2)",
    )
    parser.add_argument(
        "--laugh", type=int, default=0, choices=range(3),
        help="Risada 0-2 (padrão: 0)",
    )
    parser.add_argument(
        "--break-val", type=int, default=6, choices=range(8),
        help="Pausas 0-7 (padrão: 6)",
    )
    return parser.parse_args()


def load_model():
    import ChatTTS

    print("[chattts] Carregando modelo...", file=sys.stderr)
    chat = ChatTTS.Chat()
    loaded = chat.load(source="huggingface", compile=False)
    if not loaded:
        print("[chattts] Erro: falha ao carregar modelo ChatTTS.", file=sys.stderr)
        sys.exit(1)
    print("[chattts] Modelo carregado.", file=sys.stderr)
    return chat


def load_ref_audio(path: str, target_sr: int = 24000):
    """Carrega áudio do disco, converte para mono e reamostra para target_sr."""
    import torchaudio

    wav, sr = torchaudio.load(path)

    # Stereo → mono
    if wav.shape[0] > 1:
        wav = wav.mean(dim=0, keepdim=True)

    # Reamostrar se necessário
    if sr != target_sr:
        print(
            f"[chattts] Reamostando áudio de {sr} Hz para {target_sr} Hz...",
            file=sys.stderr,
        )
        resampler = torchaudio.transforms.Resample(orig_freq=sr, new_freq=target_sr)
        wav = resampler(wav)

    return wav.squeeze(0)  # (T,) tensor


def resolve_speaker(chat, args):
    """
    Retorna o embedding do locutor como string.
    Prioridade: --ref-audio > --spk > aleatório
    """
    if args.ref_audio:
        if not os.path.exists(args.ref_audio):
            print(
                f"[chattts] Erro: áudio de referência não encontrado: {args.ref_audio}",
                file=sys.stderr,
            )
            sys.exit(1)
        print(
            f"[chattts] Extraindo perfil de voz do áudio: {args.ref_audio}",
            file=sys.stderr,
        )
        wav = load_ref_audio(args.ref_audio)
        spk = chat.sample_audio_speaker(wav)
        print("[chattts] Perfil extraído com sucesso.", file=sys.stderr)

    elif args.spk and os.path.exists(args.spk):
        print(f"[chattts] Usando perfil salvo: {args.spk}", file=sys.stderr)
        with open(args.spk, "r") as f:
            spk = json.load(f)
        if not isinstance(spk, str):
            print(
                "[chattts] Erro: formato de perfil inválido. Regenere com --export-spk.",
                file=sys.stderr,
            )
            sys.exit(1)

    else:
        print("[chattts] Amostrando locutor aleatório...", file=sys.stderr)
        spk = chat.sample_random_speaker()

    return spk


def main():
    args = parse_args()

    import ChatTTS
    import torchaudio
    import torch
    import numpy as np

    chat = load_model()

    # Resolve o locutor
    spk = resolve_speaker(chat, args)

    # Salva o perfil de voz se solicitado
    if args.export_spk:
        export_dir = os.path.dirname(args.export_spk)
        if export_dir:
            os.makedirs(export_dir, exist_ok=True)
        with open(args.export_spk, "w") as f:
            # spk é uma str retornada pelo ChatTTS (embedding codificado)
            json.dump(spk, f)
        print(f"[chattts] Perfil salvo em: {args.export_spk}", file=sys.stderr)

    # Modo apenas extração de perfil: para aqui
    if args.sample_only:
        if not args.export_spk:
            print(
                "[chattts] Aviso: --sample-only usado sem --export-spk; nada foi salvo.",
                file=sys.stderr,
            )
        return

    # Lê o texto de entrada
    if args.file:
        if not os.path.exists(args.file):
            print(f"[chattts] Erro: arquivo não encontrado: {args.file}", file=sys.stderr)
            sys.exit(1)
        with open(args.file, "r", encoding="utf-8") as f:
            text = f.read().strip()
    elif args.text:
        text = args.text.strip()
    elif not sys.stdin.isatty():
        text = sys.stdin.read().strip()
    else:
        print(
            "[chattts] Erro: nenhum texto fornecido. Use --text, --file ou stdin.",
            file=sys.stderr,
        )
        sys.exit(1)

    if not text:
        print("[chattts] Erro: texto vazio.", file=sys.stderr)
        sys.exit(1)

    params_infer_code = ChatTTS.Chat.InferCodeParams(
        spk_emb=spk,
        temperature=args.temperature,
        top_P=0.7,
        top_K=20,
    )

    params_refine_text = ChatTTS.Chat.RefineTextParams(
        prompt=f"[oral_{args.oral}][laugh_{args.laugh}][break_{args.break_val}]",
    )

    print("[chattts] Sintetizando fala...", file=sys.stderr)
    wavs = chat.infer(
        [text],
        params_refine_text=params_refine_text,
        params_infer_code=params_infer_code,
    )

    # Garante que o diretório de saída existe
    output_dir = os.path.dirname(args.output)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    wav_tensor = torch.from_numpy(wavs[0])
    try:
        torchaudio.save(args.output, wav_tensor.unsqueeze(0), 24000)
    except Exception:
        torchaudio.save(args.output, wav_tensor, 24000)

    print(f"[chattts] Áudio salvo em: {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
