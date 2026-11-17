# Contratos de Dados e Extração (Sem Geometria)

## 1. Modelos de Domínio (Firestore & Flutter)

### 1.1. `Loteamento` (`loteamentos/{id}`)
Representa o empreendimento cadastrado manualmente ou extraído do carimbo do projeto.

| Campo | Tipo | Obrigatoriedade | Origem / Observação |
| :--- | :--- | :--- | :--- |
| `id` | `String` | Obrigatório | UUID ou `<draftId>--loteamento` |
| `construtoraId` | `String` | Obrigatório | FK da construtora proprietária |
| `name` | `String` | Obrigatório | Nome do loteamento (ex.: `Loteamento Jardim Botanico`) |
| `bairro` | `String?` | Opcional | Localidade/bairro extraído do carimbo (ex.: `Estivas`) |
| `cidade` | `String?` | Opcional | Município extraído do carimbo (ex.: `Extremoz`) |
| `uf` | `String?` | Opcional | Sigla do estado (ex.: `RN`) |
| `proprietarioNome` | `String?` | Opcional | Razão social ou nome do proprietário/empreendedor |
| `proprietarioDocumento` | `String?` | Opcional | CPF ou CNPJ do proprietário |
| `responsavelTecnicoNome` | `String?` | Opcional | Nome do responsável técnico do projeto |
| `responsavelTecnicoRegistro` | `String?` | Opcional | Registro CREA ou CAU |
| `createdAt` | `DateTime` (ISO-8601) | Obrigatório | Carimbo de criação |
| `updatedAt` | `DateTime` (ISO-8601) | Obrigatório | Carimbo de atualização |

### 1.2. `Quadra` (`quadras/{id}`)
Sem campo `geometry`.

| Campo | Tipo | Obrigatoriedade | Origem / Observação |
| :--- | :--- | :--- | :--- |
| `id` | `String` | Obrigatório | UUID ou determinístico na consolidação |
| `construtoraId` | `String` | Obrigatório | FK da construtora |
| `loteamentoId` | `String` | Obrigatório | FK do loteamento pai |
| `name` | `String` | Obrigatório | Identificação da quadra (ex.: `Quadra 28` ou `Q28`) |
| `logradouroPadrao` | `String?` | Opcional | Rua principal da quadra, quando aplicável |
| `createdAt` | `DateTime` (ISO-8601) | Obrigatório | Carimbo de criação |
| `updatedAt` | `DateTime` (ISO-8601) | Obrigatório | Carimbo de atualização |

### 1.3. `Lote` (`lotes/{id}`)
Sem campo `geometry`. Armazena medidas dimensionais, dados técnicos opcionais do PDF e resumo desnormalizado das etapas e alocações para renderização imediata no `LoteSummaryCard`.

| Grupo | Campo | Tipo | Regra / Observação |
| :--- | :--- | :--- | :--- |
| **Identificação** | `id`, `construtoraId`, `loteamentoId`, `quadraId`, `name` | `String` | Obrigatórios (ex.: `Lote 31`) |
| | `createdAt`, `updatedAt` | `DateTime` | Obrigatórios (ISO-8601) |
| **Medidas Principais** | `frenteM` | `double?` | Testada/largura em metros (ex.: `10.0`) |
| | `profundidadeM` | `double?` | Lateral/comprimento em metros (ex.: `20.0`) |
| | `areaTerrenoM2` | `double?` | Calculada automaticamente (`frenteM * profundidadeM`) ou editada manualmente (ex.: `200.0`) |
| | `areaConstruidaM2` | `double?` | Área construída em m² (ex.: `49.96`) |
| | `logradouro` | `String?` | Endereço/rua do lote (ex.: `Rua Sandoval Wanderley, s/n`) |
| **Opcionais do PDF (Quadro de Áreas)** | `taxaOcupacaoPercent` | `double?` | Taxa de ocupação em % (ex.: `24.98`) |
| | `coeficienteAproveitamento` | `double?` | Coeficiente de aproveitamento (ex.: `0.24`) |
| | `areaPermeavelM2` | `double?` | Área permeável em m² (ex.: `112.46`) |
| | `taxaPermeabilidadePercent` | `double?` | Taxa de permeabilidade em % (ex.: `56.23`) |
| | `areaImpermeavelM2` | `double?` | Área impermeável em m² (ex.: `37.58`) |
| **Opcionais do PDF (Recuos e Carimbo)** | `recuoFrontalM`, `recuoFundoM`, `recuoLateralEsquerdoM`, `recuoLateralDireitoM` | `double?` | Recuos da edificação em metros (ex.: `5.05`, `5.94`, `1.43`, `1.43`) |
| | `proprietarioNome`, `proprietarioDocumento` | `String?` | Quando específicos do lote |
| | `responsavelTecnicoNome`, `responsavelTecnicoRegistro`, `dataProjeto` | `String?` | Metadados do carimbo da prancha |
| **Resumo Desnormalizado (Cards)** | `progressoPercentual` | `int` | `0` a `100` (padrão `0`), média dos percentuais das 5 etapas |
| | `etapasConcluidasCount` | `int` | `0` a `5` (padrão `0`) |
| | `etapasTotalCount` | `int` | Padrão `5` |
| | `statusEtapasMap` | `Map<String, String>` | Chaves `muro`, `cinza1`, `cinza2`, `cinza3`, `branca` com valor `'pendente'`, `'em_andamento'` ou `'concluida'` |
| | `equipesVinculadas` | `List<Map<String, dynamic>>` | Lista de `{id, name, leaderName?, etapaId?}` |
| | `funcionariosVinculados` | `List<Map<String, dynamic>>` | Lista de `{id, name, role, etapaId?}` |

### 1.4. `Etapa` (`etapas/{id}`)
Mantém as 5 etapas padrão de `EtapaTipo` (`muro`, `cinza1`, `cinza2`, `cinza3`, `branca`) com controle de progresso e vínculo de execução.

| Campo | Tipo | Regra / Observação |
| :--- | :--- | :--- |
| `id`, `construtoraId`, `loteamentoId`, `quadraId`, `loteId`, `nome`, `ordem`, `createdAt`, `updatedAt` | Existentes | Contrato atual preservado |
| `responsavelId` | `String?` | Contrato atual preservado |
| `status` | `String` | `'pendente'` (padrão), `'em_andamento'` ou `'concluida'` |
| `percentual` | `int` | `0` a `100` (padrão `0`; `100` quando `'concluida'`; `50` sugerido quando `'em_andamento'` se não especificado) |
| `equipeId`, `equipeNome` | `String?` | Equipe vinculada diretamente à etapa (opcional) |
| `funcionarioId`, `funcionarioNome` | `String?` | Funcionário vinculado diretamente à etapa (opcional) |

**Regra de cálculo do progresso no `Lote`:**
- `progressoPercentual = round(sum(etapa.percentual for etapa in 5 etapas) / 5)`.
- Sempre que uma `Etapa` tiver `status` ou `percentual` alterado, o `WriteBatch` atualiza o documento em `etapas/{id}` e recalcula atomicamente `progressoPercentual`, `etapasConcluidasCount` e `statusEtapasMap` no documento `lotes/{loteId}`.

---

## 2. Contrato de Rascunho Tabular (`loteamentos_drafts/{draftId}`)

Substitui o contrato `FeatureCollection` GeoJSON por uma estrutura tabular revisável, compatível com PDF, DXF e DWF:

```json
{
  "construtoraId": "string",
  "targetLoteamentoId": null,
  "loteamento": {
    "name": "Loteamento Jardim Botanico",
    "bairro": "Estivas",
    "cidade": "Extremoz",
    "uf": "RN",
    "proprietarioNome": "CARNEIRO E OLIVEIRA EMPREENDIMENTOS LTDA",
    "proprietarioDocumento": "69.307.863/0001-02",
    "responsavelTecnicoNome": "JOCSA RAMOS VARELA",
    "responsavelTecnicoRegistro": "2116022975"
  },
  "status": "pendente",
  "sourceFormat": "pdf",
  "sourceFiles": [
    {
      "filename": "lote_31_q28.pdf",
      "pageCount": 1,
      "status": "processado"
    }
  ],
  "items": [
    {
      "quadra": "Quadra 28",
      "nome": "Lote 31",
      "frenteM": 10.0,
      "profundidadeM": 20.0,
      "areaTerrenoM2": 200.0,
      "areaConstruidaM2": 49.96,
      "logradouro": "Rua Sandoval Wanderley, s/n",
      "taxaOcupacaoPercent": 24.98,
      "coeficienteAproveitamento": 0.24,
      "areaPermeavelM2": 112.46,
      "taxaPermeabilidadePercent": 56.23,
      "areaImpermeavelM2": 37.58,
      "recuoFrontalM": 5.05,
      "recuoFundoM": 5.94,
      "recuoLateralEsquerdoM": 1.43,
      "recuoLateralDireitoM": 1.43,
      "dataProjeto": "outubro/26",
      "sourceFile": "lote_31_q28.pdf",
      "sourcePage": 1,
      "status": "valido"
    }
  ],
  "consolidationRequestId": null,
  "consolidationCompletedRequestId": null
}
```

### Regras de `firestore.rules` para `loteamentos_drafts/{draft_id}`
- Membro ativo da construtora pode atualizar: `loteamento`, `targetLoteamentoId`, `items`, `status`, `consolidationRequestId`, `updatedAt` (mantendo a compatibilidade de revisão e aprovação sem permitir criação/exclusão direta pelo cliente).

---

## 3. Regras de Extração de Arquivos (`functions-python`)

### 3.1. Extração de PDF (`pdf_extraction.py`)
Suporta **3 cenários no mesmo fluxo**:
1. **PDF de 1 página**: extrai o(s) lote(s) e metadados do carimbo da página.
2. **PDF multipágina**: processa cada página (`for page_index, page in enumerate(document, start=1)`), agregando os itens extraídos na lista `items` do mesmo rascunho.
3. **Múltiplos arquivos PDF**: uploads compartilhando o mesmo `draftId` (armazenado no metadado `draftId` do Storage) fazem merge atômico/transacional de seus `items` e `sourceFiles` no documento `loteamentos_drafts/{draftId}`.

**Pipeline por página:**
1. Extrair blocos de texto vetorial via `PyMuPDF` (`page.get_text("blocks")` / `page.get_text("text")`). Caso o texto extraído seja vazio ou insuficiente, aplicar fallback OCR com `pytesseract`.
2. **Parser de Carimbo / Localização**:
   - Lote e Quadra: regex para `Lote\s*([0-9A-Za-z-]+)\s*(?:da|de|,|\s|-)*\s*[Qq]uadra\s*([0-9A-Za-z-]+)` (e variações invertidas ou abreviações `Q28`, `Q-28`, `Lt 31`).
   - Loteamento: regex para `Loteamento\s+([^,\n;]+)`.
   - Localização: extração de `Logradouro`, `Bairro`, `Cidade/UF` (padrão `Cidade/UF` próximo ao campo `local:`).
   - Proprietário, CPF/CNPJ (`\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}` ou CPF), Responsável Técnico e CREA/CAU, data do projeto.
3. **Parser do Quadro Geral de Áreas**:
   - Captura valores numéricos (convertendo vírgula decimal brasileira para `float`) associados a `LOTE` / `ÁREA DO TERRENO`, `ÁREA CONSTRUÍDA`, `TAXA DE OCUPAÇÃO`, `COEFICIENTE DE APROVEITAMENTO`, `ÁREA PERMEÁVEL`, `TAXA DE PERMEABILIDADE` e `ÁREA IMPERMEÁVEL`.
4. **Parser de Cotas Lineares (`frenteM` e `profundidadeM`)**:
   - Analisa cotas lineares presentes no texto da página e seleciona o par `(frente, profundidade)` compatível com `frente * profundidade ~= areaTerrenoM2` (tolerância de 1%). Se ausente e apenas `areaTerrenoM2` existir, mantém dimensões nulas para revisão opcional.

### 3.2. Adaptação DXF e DWF (`dxf_extraction.py`, `dwf_extraction.py`)
- Mantém a leitura das entidades (`LWPOLYLINE`/`POLYLINE`/`TEXT`/`MTEXT`/`ATTRIB` e streams `W2D`), calculando área e dimensões aproximadas da envolvente de cada parcela para preencher `quadra`, `nome`, `frenteM`, `profundidadeM` e `areaTerrenoM2` no mesmo formato `items` de `loteamentos_drafts`, sem emitir objetos GeoJSON nem acionar canvas geométrico.
- Na consolidação (`firestore_utils.py`), todos os lotes materializados recebem automaticamente suas **5 etapas padrão** (`{loteId}_{tipo}` para cada `EtapaTipo`) e resumo inicial (`progressoPercentual: 0`, `etapasConcluidasCount: 0`, `etapasTotalCount: 5`), respeitando o teto de 500 operações por `WriteBatch`.
