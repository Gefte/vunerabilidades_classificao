#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_PG="${PROJECT_ROOT}/venv/bin/pg"

OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
OLLAMA_CONTAINER="ollama"
MODELS=(
  "mistral:7b"
  "falcon3:7b"
  "falcon3:10b"
  "gpt-oss:20b"
  "phi4:14b"
  "phi3:14b"
  "phi3:3.8b"
  "deepseek-r1:8b"
  "deepseek-r1:70b"
  "cogito:70b"
  "cogito:8b"
  "gemma3:27b-it-qat"
  "gemma3:12b"
  "gemma2:9b"
  "gemma2:27b"
  "granite3.2:8b"
  "huihui_ai/foundation-sec-abliterated:8b"
  "llama3.1:8b"
  "llama3.1:70b"
  "llama3.3:70b"
  "mistral-small:24b"
  "qwen2.5:7b"
  "qwen2.5:32b"
  "qwen3:8b"
  "qwen3:32b"
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
    sudo systemctl start docker
    sleep 2
  fi
  log_success "Docker esta rodando"
}

start_ollama_container() {
  if docker ps -a --format '{{.Names}}' | grep -q "^${OLLAMA_CONTAINER}$"; then
    if docker ps --format '{{.Names}}' | grep -q "^${OLLAMA_CONTAINER}$"; then
      log_info "Container ${OLLAMA_CONTAINER} ja esta rodando"
      return 0
    fi
    log_info "Container ${OLLAMA_CONTAINER} existe mas esta parado. Iniciando..."
    docker start "${OLLAMA_CONTAINER}"
    return 0
  fi

  log_info "Baixando imagem do Ollama e iniciando container..."
  docker run -d \
    -v ollama:/root/.ollama \
    -p 11434:11434 \
    --name "${OLLAMA_CONTAINER}" \
    ollama/ollama
  log_success "Container ${OLLAMA_CONTAINER} criado e iniciado"
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
  docker exec "${OLLAMA_CONTAINER}" ollama pull "${model_name}"
  log_success "Modelo ${model_name} baixado"
}

remove_model() {
  local model_name="$1"
  log_info "Removendo modelo: ${model_name}"
  docker exec "${OLLAMA_CONTAINER}" ollama rm "${model_name}" || true
}

run_experiment() {
  local model_name="$1"
  local technique="$2"
  local safe_name="${model_name//\//_}"
  local logfile="${SCRIPT_DIR}/logs/experiment_${safe_name}_${technique}.log"

  mkdir -p "${SCRIPT_DIR}/logs"

  log_info "Executando experimento: modelo=${model_name} tecnica=${technique}"
  "${VENV_PG}" run \
    --model "${model_name}" \
    --technique "${technique}" \
    --max_tokens 2000 \
    --temperature 0.2 \
    --output csv \
    >"${logfile}" 2>&1

  local exit_code=$?
  if [ $exit_code -eq 0 ]; then
    log_success "Experimento concluido: ${model_name} / ${technique}"
  else
    log_error "Experimento falhou para ${model_name} / ${technique} (exit=${exit_code}). Veja: ${logfile}"
  fi
  return $exit_code
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

  ensure_docker
  start_ollama_container
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
