# E1 — Classificação de Severidade CVSS

**Prioridade**: Alta — comparação direta com o paper base (ERRC 2025).

Avalia se o FrameworkPE classifica corretamente a severidade CVSSv3 de vulnerabilidades
identificadas em containers Docker (OpenVAS/Greenbone) **sem usar o score CVSS numérico como
entrada**. Permite comparação direta com os resultados do paper base no domínio de incidentes.

## Objetivo

Dado apenas os campos textuais de um relatório OpenVAS (NVT Name, Summary, Vulnerability Insight,
Impact), o modelo deve inferir o nível de severidade: **Informational / Low / Medium / High / Critical**.

O campo `CVSS` do CSV é excluído do input e usado apenas como ground truth (derivado automaticamente
pelo scanner a partir do score numérico).

## Hipótese

O ranking de desempenho `PHP > SHP > PRP > ZSL > HTP` observado no paper base se mantém no novo
domínio de vulnerabilidades. O contexto mais objetivo das vulnerabilidades técnicas deve facilitar
PHP e SHP pela natureza incremental da construção de contexto.

## Detalhes

| Parâmetro    | Valor |
|--------------|-------|
| Tarefa       | Classificação multiclasse: Informational / Low / Medium / High / Critical |
| Input        | NVT Name + Summary + Vulnerability Insight + Impact (sem CVSS numérico) |
| Ground truth | Campo `Severity` do CSV (derivado automaticamente do CVSS pelo scanner) |
| Técnicas     | ZSL, PHP, SHP, HTP, PRP (todas as 5) |
| Modelo       | `qwen:0.5b` via Ollama (local) |
| Métricas     | Accuracy, Precision, Recall, F1-macro, F1-weighted |

## Dataset

- **Fonte**: `../openvas_experiments_dataset.csv` (scans OpenVAS/Greenbone de containers Docker Hub)
- **Volume**: 6.000+ registros de vulnerabilidades
- **Colunas de input**: `NVT Name`, `Summary`, `Vulnerability Insight`, `Impact`
- **Target**: `Severity`

## Técnicas de Prompt

| Sigla | Nome | Estratégia |
|-------|------|-----------|
| ZSL | Zero-Shot Learning | Classificação direta sem exemplos — linha de base |
| PHP | Progressive Hint Prompting | Itera com respostas anteriores como dicas até convergir |
| SHP | Self-Hint Prompting | Auto-reflexão iterativa antes de responder |
| HTP | Hypothesis Testing Prompting | Testa H_true/H_false para cada categoria por palavras-chave |
| PRP | Progressive Rectification Prompting | Mascara keywords e força reclassificação (quebra anchor bias) |

## Taxonomia de Severidade (CVSSv3)

| Categoria | CVSS | Descrição |
|-----------|------|-----------|
| Informational | 0.0 | Dados de diagnóstico do scanner: portas abertas, banners, versões detectadas, EOL |
| Low | 0.1–3.9 | Impacto limitado, requer acesso local ou condições complexas |
| Medium | 4.0–6.9 | Impacto moderado, pode permitir acesso parcial não autorizado |
| High | 7.0–8.9 | Impacto significativo — data breach, privilege escalation, exploração remota |
| Critical | 9.0–10.0 | Impacto máximo — RCE, comprometimento total sem autenticação |

## Estrutura

```
experimento_1/
├── data/                          # Dataset OpenVAS (link simbólico ou cópia)
├── schema/
│   ├── zeroshot.yaml              # ZSL — Zero-Shot Learning
│   ├── progressive_hint.yaml      # PHP — Progressive Hint Prompting
│   ├── self_hint.yaml             # SHP — Self-Hint Prompting
│   ├── hypothesis_testing.yaml    # HTP — Hypothesis Testing Prompting
│   └── progressive_rectification.yaml  # PRP — Progressive Rectification Prompting
├── model/
├── logs/
├── output/
├── config.yaml
└── README.md
```

## Configuração

```yaml
models:
- name: "qwen:0.5b"
  provider: ollama
  temperature: 0.2
  max_tokens: 2048
```

## Como Usar

```bash
# 1. Ativar ambiente
source ../venv/bin/activate

# 2. Aplicar configurações
pg apply

# 3. Executar todas as técnicas
pg run

# 4. Ver resultados
ls output/
```

---

Criado em: 2026-05-18 | Atualizado em: 2026-05-19
