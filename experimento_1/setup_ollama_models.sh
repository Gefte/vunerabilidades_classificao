#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="${PROJECT_ROOT}/venv"
VENV_PG="${VENV_DIR}/bin/pg"
VENV_PIP="${VENV_DIR}/bin/pip"
VENV_PYTHON="${VENV_DIR}/bin/python"

OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
OLLAMA_CONTAINER="ollama"
OLLAMA_VIA_DOCKER=0
OLLAMA_PID=""
MODELS=(
#  "mistral:7b"
 # "falcon3:7b"
#  "falcon3:10b"
  "gpt-oss:20b"
#  "phi4:14b"
#  "phi3:14b"
  "phi3:3.8b"
  "deepseek-r1:8b"
#  "deepseek-r1:70b"
#  "cogito:70b"
  "cogito:8b"
#  "gemma3:27b-it-qat"
  "gemma3:12b"
  "gemma2:9b"
#  "gemma2:27b"
  "granite3.2:8b"
  "huihui_ai/foundation-sec-abliterated:8b"
  "llama3.1:8b"
#  "llama3.1:70b"
#  "llama3.3:70b"
#  "mistral-small:24b"
  "qwen2.5:7b"
#  "qwen2.5:32b"
  "qwen3:8b"
#  "qwen3:32b"
  "smollm2:1.7b"
  "tinyllama:1.1b"
)
TECHNIQUES=(
  "zeroshot"
  "progressive_hint"
  "self_hint"
  "hypothesis_testing"
  "progressive_rectification"
)
MAX_RETRIES=30
RETRY_DELAY=5

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

install_docker() {
  log_info "Docker nao encontrado. Instalando..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
  elif command -v yum &>/dev/null; then
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
  else
    curl -fsSL https://get.docker.com | sudo sh
  fi
  sudo usermod -aG docker "$USER"
  log_success "Docker instalado com sucesso"
}

ensure_docker() {
  if ! command -v docker &>/dev/null; then
    install_docker
  fi
  if ! docker info &>/dev/null; then
    log_info "Iniciando servico Docker..."
    sudo systemctl start docker 2>/dev/null || true
    sleep 2
  fi
  if docker info &>/dev/null; then
    log_success "Docker esta rodando"
    return 0
  fi
  log_warning "Docker nao esta funcional neste ambiente"
  return 1
}

try_start_ollama_docker() {
  if docker ps -a --format '{{.Names}}' | grep -q "^${OLLAMA_CONTAINER}$"; then
    if docker ps --format '{{.Names}}' | grep -q "^${OLLAMA_CONTAINER}$"; then
      log_info "Container ${OLLAMA_CONTAINER} ja esta rodando"
      return 0
    fi
    log_info "Container ${OLLAMA_CONTAINER} existe mas esta parado. Iniciando..."
    docker start "${OLLAMA_CONTAINER}" && return 0
    log_warning "Falha ao iniciar container existente, recriando..."
    docker rm -f "${OLLAMA_CONTAINER}" 2>/dev/null || true
  fi

  log_info "Baixando imagem do Ollama e iniciando container..."
  docker run -d \
    -v ollama:/root/.ollama \
    -p 11434:11434 \
    --name "${OLLAMA_CONTAINER}" \
    ollama/ollama 2>&1
}

start_ollama_native() {
  if ! command -v ollama &>/dev/null; then
    log_info "Instalando Ollama nativamente..."
    if command -v apt-get &>/dev/null; then
      sudo apt-get install -y -qq zstd
    elif command -v dnf &>/dev/null; then
      sudo dnf install -y zstd
    elif command -v yum &>/dev/null; then
      sudo yum install -y zstd
    fi
    curl -fsSL https://ollama.ai/install.sh | sh
    log_success "Ollama instalado"
  fi

  if pgrep -x ollama >/dev/null 2>&1; then
    log_info "Ollama ja esta rodando nativamente"
    return 0
  fi

  log_info "Iniciando Ollama em background..."
  ollama serve >/dev/null 2>&1 &
  OLLAMA_PID=$!
  sleep 2
}

start_ollama() {
  if ensure_docker; then
    log_info "Tentando iniciar Ollama via Docker..."
    if try_start_ollama_docker; then
      OLLAMA_VIA_DOCKER=1
      log_success "Ollama iniciado via Docker"
      return 0
    fi
    log_warning "Docker falhou ao iniciar Ollama, tentando nativo..."
  fi

  start_ollama_native
  OLLAMA_VIA_DOCKER=0
  log_success "Ollama iniciado nativamente"
}

cleanup_ollama() {
  if [ "${OLLAMA_VIA_DOCKER}" -eq 1 ]; then
    docker stop "${OLLAMA_CONTAINER}" 2>/dev/null || true
  elif [ -n "${OLLAMA_PID}" ]; then
    kill "${OLLAMA_PID}" 2>/dev/null || true
  fi
}

wait_for_ollama() {
  log_info "Aguardando Ollama ficar disponivel em ${OLLAMA_BASE_URL}..."
  local retries=0
  while [ $retries -lt $MAX_RETRIES ]; do
    if curl -sf "${OLLAMA_BASE_URL}/api/tags" >/dev/null 2>&1; then
      log_success "Ollama esta disponivel!"
      return 0
    fi
    retries=$((retries + 1))
    log_warning "Tentativa ${retries}/${MAX_RETRIES}. Aguardando ${RETRY_DELAY}s..."
    sleep $RETRY_DELAY
  done
  log_error "Ollama nao respondeu apos ${MAX_RETRIES} tentativas"
  exit 1
}

model_exists() {
  local model_name="$1"
  curl -sf "${OLLAMA_BASE_URL}/api/tags" | jq -r '.models[].name' 2>/dev/null | grep -qxF "${model_name}"
}

pull_model() {
  local model_name="$1"
  log_info "Baixando modelo: ${model_name}"
  if [ "${OLLAMA_VIA_DOCKER}" -eq 1 ]; then
    docker exec "${OLLAMA_CONTAINER}" ollama pull "${model_name}"
  else
    ollama pull "${model_name}"
  fi
  log_success "Modelo ${model_name} baixado"
}

remove_model() {
  local model_name="$1"
  log_info "Removendo modelo: ${model_name}"
  if [ "${OLLAMA_VIA_DOCKER}" -eq 1 ]; then
    docker exec "${OLLAMA_CONTAINER}" ollama rm "${model_name}" || true
  else
    ollama rm "${model_name}" || true
  fi
}

run_experiment() {
  local model_name="$1"
  local technique="$2"
  local safe_name="${model_name//\//_}"
  local logfile="${SCRIPT_DIR}/logs/experiment_${safe_name}_${technique}.log"

  mkdir -p "${SCRIPT_DIR}/logs"

  log_info "Executando experimento: modelo=${model_name} tecnica=${technique}"
  (
    cd "${SCRIPT_DIR}"
    "${VENV_PG}" run \
      --model "${model_name}" \
      --technique "${technique}" \
      --max-tokens 2000 \
      --temperature 0.2 \
      --output csv \
      >"${logfile}" 2>&1
  )

  local exit_code=$?
  if [ $exit_code -eq 0 ]; then
    log_success "Experimento concluido: ${model_name} / ${technique}"
  else
    log_error "Experimento falhou para ${model_name} / ${technique} (exit=${exit_code}). Veja: ${logfile}"
  fi
  return $exit_code
}

ensure_venv() {
  if [ ! -f "${VENV_DIR}/bin/python" ]; then
    log_info "Criando ambiente virtual em ${VENV_DIR}..."
    rm -rf "${VENV_DIR}"
    python3 -m venv "${VENV_DIR}"
    log_success "Ambiente virtual criado"
  fi

  if [ ! -f "${VENV_PG}" ]; then
    log_info "Instalando pangolin (FrameworkPE)..."
    "${VENV_PIP}" install --upgrade pip -q
    "${VENV_PIP}" install "git+https://github.com/AILabs4All/FrameworkPE.git@cli"
    log_success "pangolin instalado"
  fi

  log_info "Verificando instalacao do pg..."
  if ! "${VENV_PG}" --help >/dev/null 2>&1; then
    log_error "pg nao foi instalado corretamente"
    exit 1
  fi
  log_success "pg esta instalado e funcional"
}

push_to_branch() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD)
  log_info "Commit e push dos resultados na branch '${branch}'..."

  git add -A
  if git diff --cached --quiet; then
    log_info "Nada para commitar"
    return 0
  fi

  git commit -m "experimento: resultados com todas as tecnicas"
  git push origin "${branch}"
  log_success "Push concluido para ${branch}"
}

main() {
  log_info "=== Script de Execucao de Experimentos com Ollama ==="
  log_info "Projeto: ${SCRIPT_DIR}"
  log_info "Tecnicas: ${TECHNIQUES[*]}"
  log_info "Total de modelos: ${#MODELS[@]}"

  trap cleanup_ollama EXIT

  ensure_venv
  start_ollama
  wait_for_ollama

  local total_models=${#MODELS[@]}
  local total_techniques=${#TECHNIQUES[@]}
  local total_runs=$((total_models * total_techniques))
  local model_idx=0
  local ok=0
  local fail=0
  local failed_runs=()

  for model in "${MODELS[@]}"; do
    model_idx=$((model_idx + 1))
    echo ""
    log_info "=== [${model_idx}/${total_models}] Modelo: ${model} ==="

    if ! model_exists "${model}"; then
      pull_model "${model}"
    else
      log_info "Modelo ${model} ja esta presente localmente"
    fi

    for technique in "${TECHNIQUES[@]}"; do
      if run_experiment "${model}" "${technique}"; then
        ok=$((ok + 1))
      else
        fail=$((fail + 1))
        failed_runs+=("${model} / ${technique}")
      fi
    done

    remove_model "${model}"
  done

  echo ""
  log_info "=== Resumo Final ==="
  log_success "Sucesso: ${ok}/${total_runs}"
  if [ $fail -gt 0 ]; then
    log_error "Falhas: ${fail}/${total_runs}"
    for r in "${failed_runs[@]}"; do
      echo "  - ${r}"
    done
  fi

  push_to_branch

  if [ $fail -gt 0 ]; then
    exit 1
  fi
}

main "$@"
