# Changelog — Los Mooscles

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
