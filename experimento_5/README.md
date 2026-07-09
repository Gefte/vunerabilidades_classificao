# E5 — Transferência Cross-Domain (Generalização do Framework)

**Prioridade**: Média — argumento de generalidade do FrameworkPE para múltiplos domínios.

Quantifica o esforço de adaptação do FrameworkPE para o domínio de vulnerabilidades em containers
Docker, medindo o ganho incremental de performance a cada nível de adaptação dos prompts (L0–L3).

## Objetivo

Responder à questão: **"Quanta engenharia de adaptação é necessária para reutilizar o FrameworkPE
em um novo domínio?"** — argumento central para justificar a generalidade do framework e sua
contribuição metodológica além do domínio de incidentes (ERRC 2025).

## Níveis de Adaptação

| Nível | Descrição | Hipótese |
|-------|-----------|----------|
| **L0 — Zero adaptação** | Prompts NIST SP 800-61r3 aplicados diretamente em dados de vulnerabilidades | Performance próxima ao aleatório |
| **L1 — Taxonomia adaptada** | Troca NIST por CVSSv3, mantém estilo de incidente | Ganho significativo |
| **L2 — Domínio adaptado** | L1 + contexto OpenVAS/scanner nos prompts | Ganho adicional moderado |
| **L3 — Otimizado** | Prompts completamente redesenhados para vulnerabilidades | Referência superior |

## Detalhes

| Parâmetro    | Valor |
|--------------|-------|
| Tarefa       | Classificação de Severidade CVSS (igual ao E1) |
| Input        | NVT Name + Summary + Vulnerability Insight + Impact |
| Ground truth | Campo `Severity` do CSV (automático) |
| Técnicas     | ZSL, PHP, SHP, HTP, PRP × 4 níveis = **20 schemas** |
| Modelo       | `qwen:0.5b` via Ollama (local) |
| Métricas     | Accuracy, F1-macro (por técnica × por nível) |

## Schemas por Nível (20 arquivos)

| Nível | ZSL | PHP | SHP | HTP | PRP |
|-------|-----|-----|-----|-----|-----|
| L0 | `zeroshot_l0` | `progressive_hint_l0` | `self_hint_l0` | `hypothesis_testing_l0` | `progressive_rectification_l0` |
| L1 | `zeroshot_l1` | `progressive_hint_l1` | `self_hint_l1` | `hypothesis_testing_l1` | `progressive_rectification_l1` |
| L2 | `zeroshot_l2` | `progressive_hint_l2` | `self_hint_l2` | `hypothesis_testing_l2` | `progressive_rectification_l2` |
| L3 | `zeroshot_l3` | `progressive_hint_l3` | `self_hint_l3` | `hypothesis_testing_l3` | `progressive_rectification_l3` |

## Relação com outros Experimentos

- **L3 do E5** ≈ **E1**: Mesmos prompts otimizados, mesma task, mesmo input.
- **E5 vs E1**: E5 adiciona a análise incremental L0→L3; E1 é o resultado com prompts L3.
- O delta `L3 − L0` quantifica o custo total de adaptação cross-domain por técnica.

## Estrutura

```
experimento_5/
├── data/
├── schema/
│   ├── zeroshot_l0.yaml ... progressive_rectification_l0.yaml   # 5 arquivos L0
│   ├── zeroshot_l1.yaml ... progressive_rectification_l1.yaml   # 5 arquivos L1
│   ├── zeroshot_l2.yaml ... progressive_rectification_l2.yaml   # 5 arquivos L2
│   └── zeroshot_l3.yaml ... progressive_rectification_l3.yaml   # 5 arquivos L3
├── model/
├── logs/
├── output/
├── config.yaml
└── README.md
```

## Como Usar

```bash
source ../venv/bin/activate
pg apply
pg run       # executa todos os 20 schemas automaticamente
ls output/
```

---

Criado em: 2026-05-18 | Atualizado em: 2026-05-19
