# E4 — Priorização Container-Aware (Contribuição Original)

**Prioridade**: Alta — contribuição original nova para container security e DevSecOps.

Classifica a urgência de correção de vulnerabilidades **considerando o contexto específico de
containers Docker**, indo além da severidade genérica do CVSS. A taxonomia proposta integra
CVSS, tipo de solução, protocolo de porta e confiança da detecção.

## Objetivo

Desenvolver e avaliar uma taxonomia de priorização container-aware que possa ser integrada em
pipelines de CI/CD com security gates automatizados, onde a decisão de bloquear ou permitir
um deploy depende da classificação da vulnerabilidade.

## Taxonomia Container-Aware

| Classe | Critério de derivação automática | Ação recomendada |
|--------|----------------------------------|------------------|
| **Crítico-Container** | CVSS ≥ 9.0 AND Solution Type = WillNotFix AND Port Protocol = tcp | Isolamento imediato — bloquear deploy |
| **Alto-Remediável** | CVSS ≥ 7.0 AND Solution Type = VendorFix | Patch prioritário na próxima sprint |
| **Médio-Monitorar** | CVSS ∈ [4.0, 7.0) OR exploração requer condições específicas | Monitorar e agendar remediação |
| **Baixo-Aceitar** | CVSS < 4.0 OR QoD < 50 (baixa confiança na detecção) | Aceitar risco ou adiar |

## Ground Truth — Derivação Automática por Regras

```python
def classify_container_priority(row):
    cvss = float(row["CVSS"])
    sol  = row["Solution Type"]
    qod  = int(row["QoD"])
    if cvss >= 9.0 and sol == "WillNotFix" and row["Port Protocol"] == "tcp":
        return "Crítico-Container"
    elif cvss >= 7.0 and sol == "VendorFix":
        return "Alto-Remediável"
    elif cvss >= 4.0 or qod >= 50:
        return "Médio-Monitorar"
    return "Baixo-Aceitar"
```

## Detalhes

| Parâmetro    | Valor |
|--------------|-------|
| Tarefa       | Classificação: Crítico-Container / Alto-Remediável / Médio-Monitorar / Baixo-Aceitar |
| Input        | NVT Name + Summary + CVSS + Solution Type + Port Protocol + QoD |
| Ground truth | Derivado por regras (função acima) |
| Técnicas     | ZSL, PHP, SHP, HTP, PRP |
| Modelo       | `qwen:0.5b` via Ollama (local) |
| Métricas     | Accuracy, F1-macro |

## Valor Científico

- **Aplicação nova do FrameworkPE** para um contexto operacional específico (DevSecOps / container security).
- Taxonomia ajustável para pipelines CI/CD com security gates automatizados.
- Demonstra extensibilidade do FrameworkPE além da classificação acadêmica de incidentes.

## Estrutura

```
experimento_4/
├── data/
├── schema/
│   ├── zeroshot.yaml
│   ├── progressive_hint.yaml
│   ├── self_hint.yaml
│   ├── hypothesis_testing.yaml
│   └── progressive_rectification.yaml
├── model/
├── logs/
├── output/
├── config.yaml
└── README.md
```

## Como Usar

```bash
source ../venv/bin/activate

# Antes: gerar campo de ground truth no dataset
# python3 gerar_ground_truth_e4.py

pg apply
pg run
ls output/
```

---

Criado em: 2026-05-18 | Atualizado em: 2026-05-19
