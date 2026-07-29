# Changelog — Los Mooscles

## 2.5.1 (Build 229) — 29/07/2026

### ✨ Melhorias no Compartilhamento de Rotinas
- **Criação Automática de Exercícios Faltantes**: Ao exportar uma rotina, as definições completas dos exercícios (nome, músculo, tipo de medição, notas) agora são incluídas no código gerado. Quando o destinatário importa a rotina, o aplicativo verifica se os exercícios existem na biblioteca dele — caso algum exercício personalizado não exista, ele é criado automaticamente na biblioteca do destinatário!

---
## 2.5.0 (Build 228) — 29/07/2026

### ✨ Novidades
- **Sugestões de Treino com Inteligência Artificial (Gemini)**: O app agora integra o Google Gemini AI diretamente na tela de Planejamento. Ao clicar no ícone de varinha mágica ✨ em qualquer dia do cronograma, a IA analisa o seu histórico de treinos e gera dicas personalizadas de carga e repetições para cada exercício planejado naquele dia. As dicas ficam salvas na tela e podem ser ocultadas ou exibidas com um toque.
- **Compartilhamento de Rotinas via Código**: Agora é possível exportar qualquer rotina como um código de texto e importar rotinas compartilhadas por outras pessoas. Basta clicar no ícone de compartilhar dentro da rotina ou usar o novo botão de importar (ícone de download) na aba de Rotinas.
- **Conquistas e Gamificação**: Novo sistema de medalhas e conquistas desbloqueáveis conforme você evolui nos treinos. Acesse em Perfil → Minhas Conquistas.
- **Gráfico de Progressão por Exercício**: Nova visualização na aba de Análise mostrando a evolução de carga e repetições de qualquer exercício ao longo do tempo, com gráfico interativo e seletor de exercício.
- **Mapa de Calor Muscular Aprimorado**: O heatmap da aba de Análise agora exibe uma silhueta humana animada indicando visualmente quais grupos musculares foram mais trabalhados no período selecionado.
- **Navegação Semanal no Planejamento**: Dois novos botões de seta permitem avançar ou retroceder o cronograma semanal inteiro com um toque, sem gerar nenhum registro automático de treino.

### 🐛 Correções
- Removida a sugestão estática de carga (+5%) da tela de treino, que foi substituída pela sugestão inteligente com IA na tela de Planejamento.

---
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
