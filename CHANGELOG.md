# Changelog — Los Mooscles

## 2.4.0 (Build 227) — 28/07/2026

### ✨ Novidades
- **Descanso Ativo — Dados do Próximo Exercício**: Enquanto descansa entre séries, a tela agora exibe diretamente a carga e o número de repetições planejados para a próxima série (ex: `12 reps • 40 kg`), tanto no iOS quanto no Apple Watch.
- **Botões de Ajuste do Timer**: Os botões de incremento/decremento do timer de descanso agora mostram claramente `+15s` e `-15s` para deixar a ação mais intuitiva.
- **Dynamic Island (Cardio)**: Corrigido o bug onde o temporizador global do treino na Dynamic Island ficava "travado" ou voltando para o início quando o app estava em segundo plano durante treinos de Cardio. O relógio agora flui continuamente sem interrupções.

### 🐛 Correções
- **Dynamic Island**: O timer de treino na Dynamic Island agora usa a data absoluta de início do treino como referência (em vez de segundos relativos), garantindo que o contador continue de onde parou, sem resetar ao atualizar a UI.
- **Apple Watch — Descanso Ativo**: O relógio agora recebe as informações de carga e repetições da próxima série via WatchConnectivity, exibindo-as discretamente abaixo do número da série no timer de descanso.

---
## 2.3.0 — 27/07/2026


### ✨ Novidades
- **Analytics & Progresso (Nova Aba)**: Gráficos de volume semanal e um Mapa de Calor (Heatmap) mostrando quais músculos foram mais exigidos recentemente.
- **Sugestões de Sobrecarga Progressiva**: O app agora analisa seu último treino e sugere de forma inteligente (+5% de carga) a meta para cada série no treino atual.
- **Compartilhamento Social**: Novo "Workout Share Card" super premium, integrado nativamente ao iOS. Gere um card de conclusão do seu treino para compartilhar nas redes sociais com um único clique.
- **Botão "Descansar Hoje"**: Atraso no treino? Aperte o botão de Descansar Hoje na tela inicial. Todo o seu planejamento semanal (segunda a domingo) será deslocado exatamente 1 dia para a frente de forma inteligente, mantendo sua rotina e intervalos perfeitos.

### 🐛 Correções & Ajustes
- Integrações offline para o Apple Watch reforçadas com enfileiramento (queue) para evitar perda de dados quando o app entra em suspensão.
- Haptics (vibrações sutis) melhorados em botões de séries concluídas e descanso.
- Refinamentos no `intl` e conflitos de compilação da biblioteca de UI (`fl_chart`).

---
## 2.2.0 (Build 172) — 15/07/2026

### 🛡 Recuperação de Dados e Sincronização
- **Recuperação de Emergência**: Novo botão "Forçar Download da Nuvem" no Perfil para resgatar treinos e rotinas órfãos em caso de falha local.
- **Sincronização Blindada**: Parsing de dados na nuvem reescrito com proteção (try-catch) bloco a bloco, garantindo que um treino corrompido nunca mais apague o histórico inteiro.
- **Biblioteca Segura**: A Biblioteca de Exercícios agora também é sincronizada em uma subcoleção isolada na nuvem (junto com treinos e modelos), protegendo-a contra perdas locais.

---

## 2.2.0 (Build 170) — 15/07/2026

### ✨ Novidades
- **Central de Notificações**: Novo painel dentro do Perfil para controle total das suas notificações:
  - **Lembretes de Água** com 4 níveis de intensidade: Agressivo (1h), Padrão (2h), Suave (4h) ou Desativado.
  - Opção de **Silenciar à Noite** — nenhum aviso de água entre 22h e 08h.
  - **Notificações de Descanso** configuráveis: banners completos ou apenas a Ilha Dinâmica (sem barulho, sem banner intrusivo).
  - **Lembretes Motivacionais** (treino) com chave on/off.

### 🎨 Melhorias de Design
- **Tela de Descanso no Apple Watch** totalmente redesenhada no padrão Premium:
  - Contagem regressiva enorme e centralizada.
  - Anel de progresso de borda a borda com efeito Glow.
  - Card glassmorphism para o próximo exercício.
  - Animação de "respiração" no fundo.
  - Botão de pular maior e mais fácil de tocar durante o treino.

### 🐛 Correções
- Corrigido erro de compilação na nova tela de configurações de notificações.

---

## 2.1.0 (Build 168)
- Configurações de notificação (base), sincronização iOS/WatchOS, launch screen sem flash branco.
