# Borba Design System — Core Design

> **Regra mestra:** TODO e QUALQUER design feito para André Borba (Figma, HTML, artifacts, slides, mockups, protótipos, código de UI) DEVE seguir este padrão. Sem exceções, sem "variações criativas" de paleta, fonte ou raio de borda.

Estética: **terminal / Bloomberg / editorial técnico**. Fundo azul meia-noite, texto branco, cantos 100% retos, bordas de 1px, labels mono em Electric Blue, inversão instantânea preto↔branco no hover.

---

## 1. Paleta de cores

### 1.1 Base

| Token | HSL | Hex aprox. | Uso |
|---|---|---|---|
| `background` / `borba-midnight` | `220 100% 3%` | `#000510` | Fundo geral (Azul Meia-noite) |
| `foreground` / `borba-white` | `0 0% 100%` | `#FFFFFF` | Texto principal (branco puro) |
| `secondary` / `borba-grey` | `204 13% 60%` | `#8899A6` | Texto secundário (cinza frio) |
| `accent` / `borba-blue` | `208 100% 43%` | `#0074D9` | Electric Blue — período do logo, ícones, destaques, labels mono pequenos |

### 1.2 Estruturais

| Token | HSL | Hex aprox. | Uso |
|---|---|---|---|
| `card` | `220 100% 3%` | `#000510` | Fundo de cards (mesmo tom do bg) |
| `popover` | `220 100% 5%` | `#00081A` | Fundo de popovers (levemente acima do bg) |
| `muted` | `0 0% 20%` | `#333333` | Cinza escuro (bloco/cinza) |
| `muted-foreground` | `204 13% 60%` | `#8899A6` | Texto sobre muted |
| `border` / `input` / `borba-border` | `0 0% 20%` | `#333333` | Bordas de 1px em todas as seções |
| `primary` | `0 0% 100%` | `#FFFFFF` | Botões primários (branco, com inversão preto↔branco no hover) |
| `destructive` | `0 84.2% 60.2%` | `#EF4444` | Erros |
| `ring` | `208 100% 43%` | `#0074D9` | Foco de inputs |

> Nota: a especificação original lista `card / popover` como `220 100% 3% / 5%`. Interpretação adotada: card = 3% (igual ao bg), popover = 5%. Ambos são quase indistinguíveis do fundo; a separação visual vem da **borda de 1px**, não do fill.

### 1.3 Extras (usados pontualmente)

| Elemento | Valor |
|---|---|
| Verde de status | `text-green-500` (`#22C55E`) — indicador `● Operational` no footer |
| Terminal | Fundo `bg-black` (`#000000`) + texto Electric Blue. O terminal fica preto independente do tema |
| Glassmorphism (header) | `rgba(0, 5, 16, 0.8)` + `backdrop-filter: blur(12px)` |
| Blur decorativo | Blobs `borba-blue` a 10% (`bg-borba-blue/10`); grids/partículas com opacidade entre 5% e 20% |

### 1.4 Variáveis CSS (referência)

```css
:root {
  --background: 220 100% 3%;
  --foreground: 0 0% 100%;
  --card: 220 100% 3%;
  --card-foreground: 0 0% 100%;
  --popover: 220 100% 5%;
  --popover-foreground: 0 0% 100%;
  --primary: 0 0% 100%;
  --primary-foreground: 220 100% 3%;
  --secondary: 204 13% 60%;
  --secondary-foreground: 220 100% 3%;
  --muted: 0 0% 20%;
  --muted-foreground: 204 13% 60%;
  --accent: 208 100% 43%;
  --accent-foreground: 0 0% 100%;
  --destructive: 0 84.2% 60.2%;
  --destructive-foreground: 0 0% 100%;
  --border: 0 0% 20%;
  --input: 0 0% 20%;
  --ring: 208 100% 43%;
  --radius: 0rem;
}
```

---

## 2. Tipografia

Três fontes, todas do Google Fonts.

| Família | Fonte | Pesos | Uso |
|---|---|---|---|
| Sans-serif (padrão) | **Inter** | 400, 500, 600, 700, 800, 900 | Corpo de texto; headlines principais (`font-black` no hero) |
| Monospace (dados/terminal) | **JetBrains Mono** (fallback **Roboto Mono**) | 400, 500, 600 | Labels técnicos, terminal, tabelas, timestamps UTC, footer, botões de comando |
| Serif (elegante/acadêmico) | **Playfair Display** | 400, 700, 900 | Títulos de relatórios estilo "Jane Street" (páginas Initiatives); contraste editorial |

Utility `.font-mono-data`: JetBrains Mono com `font-variant-ligatures: none` — para dados de terminal.

### 2.1 Escala tipográfica típica

| Papel | Classe Tailwind | Tamanho | Peso / extras |
|---|---|---|---|
| Hero H1 | `text-7xl` → `text-9xl` | 72–192 px | `font-black`, `tracking-tight` |
| Section headings | `text-5xl` → `text-8xl` | 48–96 px | `font-bold` |
| Card titles | `text-3xl` | 30 px | `font-bold` |
| Body | `text-lg` / `text-xl` | 18–20 px | `font-light`, `tracking-wide` |
| Labels técnicos (mono) | `text-xs` | 12 px | `tracking-wider` ou `tracking-widest` |
| Footer / timestamps | `text-xs` / `text-sm` | 12–14 px | `font-mono` |

---

## 3. Detalhes visuais

- `--radius: 0rem` — **cantos 100% retos, zero border-radius**, em tudo (botões, inputs, cards, avatares, chips).
- Bordas: **1px sólidas** (`#333333`); transições **cortantes** entre seções — **sem gradientes suaves**.
- Sem sombras suaves/elevation. Hierarquia por borda, tipografia e contraste, não por sombra.
- Ícones e destaques em Electric Blue (`#0074D9`).
- Labels técnicos pequenos: JetBrains Mono, caixa alta, `tracking-widest`, Electric Blue ou cinza `#8899A6`.

### 3.1 Animações

| Nome | Duração / ritmo | Uso |
|---|---|---|
| `grid-pulse` | 4s | Grid decorativo de fundo |
| `float` | 6s | Blobs/partículas decorativas |
| `typing-blink` | 1s `step-end` | Cursor de digitação |
| scramble do logo | ~2s | Animação de entrada do logo |
| digitação do terminal | 50 ms/char | Efeito de typing no terminal |

### 3.2 Botões

- **Primário:** fundo `#FFFFFF`, texto `#000510`, sem raio. Hover: **inversão instantânea** (fundo `#000510`/preto, texto branco, borda 1px branca), `duration-300`.
- **Secundário/outline:** fundo transparente, borda 1px `#333333`, texto branco. Hover: inversão (fundo branco, texto preto).
- Botões de comando: JetBrains Mono, caixa alta, `tracking-wider`.
- **Foco:** anel (`ring`) em Electric Blue `#0074D9`.
- **Destrutivo:** `#EF4444`.

---

## 4. Checklist para qualquer design novo

- [ ] Fundo `#000510`; texto `#FFFFFF`; secundário `#8899A6`; destaque `#0074D9`.
- [ ] Todas as bordas 1px `#333333`; raio **0** em tudo.
- [ ] Inter para corpo/headlines, JetBrains Mono para labels/dados/timestamps, Playfair Display só em títulos editoriais.
- [ ] Sem gradientes suaves, sem sombras, sem cantos arredondados.
- [ ] Hover de botão = inversão preto↔branco.
- [ ] Foco = ring Electric Blue.
- [ ] Erros = `#EF4444`; status OK = `#22C55E`.
- [ ] Terminal/blocos de código = fundo `#000000` + texto Electric Blue.
