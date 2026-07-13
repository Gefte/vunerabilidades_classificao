#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python)}"
CONFIG_PATH="${PROJECT_ROOT}/config/default_config.json"
MODEL_KEY=""
OLLAMA_MODEL=""
REMOVE_MODEL=1
OLLAMA_PID=""

if [[ -z "${PYTHON_BIN}" ]]; then
  echo "[ERROR] Python 3 não encontrado" >&2
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Uso: $0 <args do main.py>" >&2
  echo "Exemplo: $0 data/ --columns Pedido --model ollama_mistral --technique progressive_hint" >&2
  exit 1
fi

ORIGINAL_ARGS=("$@")

set -- "$@"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      if [[ $# -lt 2 ]]; then
        echo "[ERROR] --model requer um valor" >&2
        exit 1
      fi
      MODEL_KEY="$2"
      shift 2
      ;;
    --config)
      if [[ $# -lt 2 ]]; then
        echo "[ERROR] --config requer um valor" >&2
        exit 1
      fi
  if [[ "$2" = /* ]]; then
        CONFIG_PATH="$2"
      else
        CONFIG_PATH="${PROJECT_ROOT}/$2"
      fi
      shift 2
      ;;
    --help|-h)
      "${PYTHON_BIN}" "${PROJECT_ROOT}/main.py" --help
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "${MODEL_KEY}" ]]; then
  echo "[ERROR] Informe o modelo com --model" >&2
  exit 1
fi

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "[ERROR] Arquivo de configuração não encontrado: ${CONFIG_PATH}" >&2
  exit 1
fi

CONFIG_OUTPUT="$(
  CONFIG_PATH="${CONFIG_PATH}" MODEL_KEY="${MODEL_KEY}" \
  "${PYTHON_BIN}" <<'PY'
import json
import os
import sys

config_path = os.environ["CONFIG_PATH"]
model_key = os.environ["MODEL_KEY"]

with open(config_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

model_cfg = data.get("models", {}).get(model_key)
if not model_cfg:
    print("::error::")
    sys.exit(0)

provider = model_cfg.get("provider", "")
model_name = model_cfg.get("model", "")
print(f"{provider}::{model_name}")
PY
)"

if [[ -z "${CONFIG_OUTPUT}" || "${CONFIG_OUTPUT}" == "::error::" ]]; then
  echo "[ERROR] Modelo ${MODEL_KEY} não encontrado na configuração" >&2
  exit 1
fi

PROVIDER="${CONFIG_OUTPUT%%::*}"
OLLAMA_MODEL="${CONFIG_OUTPUT##*::}"

if [[ "${PROVIDER}" != "ollama" ]]; then
  exec "${PYTHON_BIN}" "${PROJECT_ROOT}/main.py" "${ORIGINAL_ARGS[@]}"
fi

if [[ ${OLLAMA_KEEP_MODELS:-0} == 1 ]]; then
  REMOVE_MODEL=0
fi

cleanup() {
  local exit_code=$?
  if [[ -n "${OLLAMA_PID}" ]]; then
    kill "${OLLAMA_PID}" >/dev/null 2>&1 || true
  fi
  if [[ ${REMOVE_MODEL} -eq 1 && -n "${OLLAMA_MODEL}" ]]; then
    ollama rm "${OLLAMA_MODEL}" >/dev/null 2>&1 || true
  fi
  exit "${exit_code}"
}

trap cleanup EXIT

if ! command -v ollama >/dev/null 2>&1; then
  echo "[INFO] Ollama não encontrado. Instalando..."
  if ! command -v curl >/dev/null 2>&1; then
    echo "[ERROR] curl é necessário para instalar o Ollama" >&2
    exit 1
  fi
  curl -fsSL https://ollama.ai/install.sh | sh
fi

OLLAMA_ENDPOINT="${OLLAMA_HOST:-http://localhost:11434}"

if ! curl -sf "${OLLAMA_ENDPOINT}/api/version" >/dev/null 2>&1; then
  echo "[INFO] Iniciando serviço Ollama em background"
  ollama serve >/dev/null 2>&1 &
  OLLAMA_PID=$!
  sleep 2
  if ! curl -sf "${OLLAMA_ENDPOINT}/api/version" >/dev/null 2>&1; then
    echo "[ERROR] Não foi possível iniciar o serviço Ollama em ${OLLAMA_ENDPOINT}" >&2
    exit 1
  fi
fi

if ! ollama show "${OLLAMA_MODEL}" >/dev/null 2>&1; then
  echo "[INFO] Modelo ${OLLAMA_MODEL} não encontrado. Fazendo download..."
  ollama pull "${OLLAMA_MODEL}"
else
  echo "[INFO] Modelo ${OLLAMA_MODEL} encontrado localmente"
fi

echo "[INFO] Executando classificação com ${MODEL_KEY} (${OLLAMA_MODEL})"
"${PYTHON_BIN}" "${PROJECT_ROOT}/main.py" "${ORIGINAL_ARGS[@]}"
