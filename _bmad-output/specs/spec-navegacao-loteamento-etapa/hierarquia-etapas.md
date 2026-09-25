# Hierarquia Padrão de Etapas por Lote

Cada **Lote** possui um detalhamento interno que se ramifica em múltiplas **Etapas** sequenciais/paralelas, e cada Etapa possui a sua respectiva **Equipe** alocada.

A árvore de domínio imposta é a seguinte:

```text
LOTEAMENTO
    │
    └── QUADRA
          │
          └── LOTE
                │
                ├── ETAPA — MURO
                │      └── EQUIPE
                │
                ├── ETAPA — CINZA / 1ª
                │      └── EQUIPE
                │
                ├── ETAPA — CINZA / 2ª
                │      └── EQUIPE
                │
                ├── ETAPA — CINZA / 3ª
                │      └── EQUIPE
                │
                └── ETAPA — BRANCA / ACABAMENTO
                       └── EQUIPE
```

Esta estrutura define a visualização para navegação profunda no aplicativo (drill-down). Ao visualizar um Lote, a interface exibirá todas essas etapas disponíveis para entrada.
