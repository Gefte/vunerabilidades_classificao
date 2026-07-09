# E2 — Classificação do Tipo de Solução (Triagem de Remediação)

**Prioridade**: Alta — valor prático imediato para DevSecOps.

Classifica automaticamente a ação de remediação necessária para vulnerabilidades identificadas
em containers Docker, apoiando decisões de priorização em pipelines DevSecOps.

## Objetivo

Dado o nome da vulnerabilidade, o resumo, a solução recomendada e o software afetado (campos
do OpenVAS), o modelo deve classificar o tipo de solução: **VendorFix / WillNotFix / Workaround / Mitigation**.

O campo `Solution Type` do CSV é excluído do input e usado como ground truth (anotação automática do scanner).

Valor científico: testa se o modelo consegue raciocinar sobre viabilidade de remediação — tarefa que
vai além da classificação categórica simples. A variação sem o campo `Solution` simula cenários de
zero-day onde nenhum patch está disponível e a decisão é tomada com base apenas no contexto técnico.

## Detalhes

| Parâmetro    | Valor |
|--------------|-------|
| Tarefa       | Classificação: VendorFix / WillNotFix / Workaround / Mitigation |
| Input        | NVT Name + Summary + Solution + Affected Software/OS |
| Ground truth | Campo `Solution Type` do CSV (automático) |
| Variação     | Testar também sem o campo `Solution` para simular vulnerabilidade zero-day |
| Técnicas     | ZSL, PHP, SHP, HTP, PRP (todas as 5) |
| Modelo       | `qwen:0.5b` via Ollama (local) |
| Métricas     | Accuracy, F1-macro |

## Dataset

- **Fonte**: `../openvas_experiments_dataset.csv`
- **Colunas de input**: `NVT Name`, `Summary`, `Solution`, `Affected Software/OS`
- **Target**: `Solution Type`

## Técnicas de Prompt

| Sigla | Nome | Estratégia |
|-------|------|-----------|
| ZSL | Zero-Shot Learning | Classificação direta — linha de base |
| PHP | Progressive Hint Prompting | Raciocínio iterativo por dicas |
| SHP | Self-Hint Prompting | Auto-reflexão antes de classificar |
| HTP | Hypothesis Testing Prompting | Testa hipóteses por tipo de remediação |
| PRP | Progressive Rectification Prompting | Quebra anchor bias com mascaramento |

## Taxonomia de Tipo de Solução (OpenVAS)

| Categoria | Descrição |
|-----------|-----------|
| VendorFix | Patch ou atualização oficial do vendor disponível. Aplicar a correção. |
| WillNotFix | O vendor não lançará correção (EOL, deprecado, risco aceito). |
| Workaround | Sem patch oficial, mas existe solução alternativa (configuração, desabilitar feature). |
| Mitigation | Mitigação parcial possível (WAF, segmentação de rede, controles de acesso). |

## Variação Experimental: Cenário Zero-Day

Para simular cenários onde nenhum patch existe, execute uma segunda rodada **sem** o campo `Solution`
nos `input_columns` do config.yaml. Isso força o modelo a decidir com base apenas no contexto técnico
(NVT Name + Summary + Affected Software/OS).

## Estrutura

```
experimento_2/
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
pg apply
pg run
ls output/
```

---

Criado em: 2026-05-18 | Atualizado em: 2026-05-19
