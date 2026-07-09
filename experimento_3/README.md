# E3 — Ablation de Configurações de Input (Contribuição Metodológica)

**Prioridade**: Média — contribuição metodológica sobre impacto do input nas técnicas de PE.

Avalia o impacto da estrutura e riqueza do input nas técnicas de Prompt Engineering para
classificação de severidade CVSS — questão inédita em relação ao paper base, que usava
relatos narrativos homogêneos de incidentes.

## Objetivo

Mantendo a mesma task do E1 (Severidade CVSS), testa 5 configurações de entrada crescentemente
ricas para revelar **qual nível de detalhe do relatório OpenVAS é necessário para cada técnica de PE**.

Hipótese: PHP e SHP, por construírem contexto incremental, são mais robustos à variação do
input em comparação com HTP e ZSL.

## Configurações de Ablação

| Configuração | Campos utilizados | Propósito |
|-------------|-------------------|-----------|
| C1 — Texto mínimo | Apenas `NVT Name` | Limite inferior — título técnico curto |
| C2 — Texto enriquecido | `NVT Name` + `Summary` + `Vulnerability Insight` | Contexto textual completo |
| C3 — Texto + CVEs | C2 + `CVEs` | Adiciona referências externas |
| C4 — Texto + metadados | C3 + `Port` + `Affected Software/OS` | Adiciona contexto de implantação |
| C5 — Estruturado completo | Todos os campos textuais + `CVSS` numérico | Limite superior (upper bound) |

## Detalhes

| Parâmetro    | Valor |
|--------------|-------|
| Tarefa       | Classificação de Severidade CVSS (igual ao E1) |
| Ground truth | Campo `Severity` do CSV (automático) |
| Técnicas     | ZSL, PHP, SHP, HTP, PRP |
| Modelo       | `qwen:0.5b` via Ollama (local) |
| Métricas     | Accuracy, F1-macro (por configuração e por técnica) |

## Como Executar as 5 Configurações

Cada configuração requer ajustar `input_columns` no `config.yaml` antes de executar `pg run`.

```bash
source ../venv/bin/activate
pg apply
```

### C1 — Texto mínimo
```yaml
data:
  input_columns: [NVT Name]
```

### C2 — Texto enriquecido
```yaml
data:
  input_columns: [NVT Name, Summary, Vulnerability Insight]
```

### C3 — Texto + CVEs
```yaml
data:
  input_columns: [NVT Name, Summary, Vulnerability Insight, CVEs]
```

### C4 — Texto + metadados
```yaml
data:
  input_columns: [NVT Name, Summary, Vulnerability Insight, CVEs, Port, "Affected Software/OS"]
```

### C5 — Estruturado completo (upper bound)
```yaml
data:
  input_columns: [NVT Name, Summary, Vulnerability Insight, CVEs, Port, "Affected Software/OS", CVSS]
```

O `config.yaml` padrão inclui todos os campos (C5), permitindo testes diretos. Para C1–C4,
edite `input_columns` antes de cada execução.

## Estrutura

```
experimento_3/
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

## Relação com outros Experimentos

- **E1**: Usa configuração próxima a C2 (sem CVSS numérico) como padrão.
- **E3**: Testa sistematicamente C1–C5 para todas as técnicas.
- O ganho de C5 sobre E1 quantifica o valor do CVSS numérico como feature de input.

---

Criado em: 2026-05-18 | Atualizado em: 2026-05-19
