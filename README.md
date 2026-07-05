# Los Mooscles 🏋️

Um aplicativo moderno e premium de acompanhamento de treinos e dieta, projetado com a estética **Liquid Glassmorphism** e sincronização em tempo real entre o app móvel, Apple Watch (via watchOS) e Firebase.

## 🚀 Recursos Principais

### 🏋️ Treinos e Academia
- **Cronômetro inteligente**: Temporizador de descanso adaptativo que monitora repetições de falha sem reiniciar incondicionalmente.
- **Biblioteca de Exercícios**: Cadastro e customização detalhada de exercícios por grupo muscular.
- **Rotinas Personalizadas**: Planeje seus treinos semanais com metas de séries, repetições e RPE.

### 💧 Dieta e Hidratação
- **Registro de Consumo**: Controle de ingestão de água com suporte à Digital Crown no Apple Watch.
- **Metas Diárias**: Acompanhamento de macronutrientes (proteínas, carboidratos e gorduras).
- **Jejum Intermitente**: Temporizadores dedicados para controle de períodos de jejum.

### ⌚ Sincronização Apple Watch e Watch Extension
- **Widget do Watch**: Complications atualizadas em tempo real usando a suíte compartilhada de UserDefaults (`group.com.vicente.losmooscles`).
- **Ações Rápidas**: Adicione ou remova água e acompanhe o progresso do seu treino direto do pulso.

### 🏗️ Arquitetura do Estado (Facade & Sub-Provedores)
- O aplicativo utiliza a arquitetura especializada de sub-provedores (`WorkoutProvider`, `DietProvider`, `ProfileProvider`) e `ProxyProvider` para isolar a renderização da interface e otimizar o desempenho (rebuilds granulares).
- Mantém o `TrackerProvider` como uma fachada (Facade Pattern) para retrocompatibilidade.

### 📴 Sincronização Incremental & Fila Offline
- **SyncQueueService**: Fila persistida no dispositivo (`SharedPreferences`) que captura e deduplica operações do Firebase durante momentos sem conexão de rede.
- **Drain automático**: As tarefas são sincronizadas e limpas automaticamente assim que a conectividade do dispositivo é restabelecida.
- **Indicador Visual**: Banner superior que avisa o usuário quando o app entra em modo offline.

## 🛠️ Tecnologias Utilizadas
- **Flutter & Dart**
- **State Management**: Provider & MultiProvider
- **Banco de Dados & Auth**: Firebase Firestore & Firebase Authentication
- **Analytics**: Firebase Analytics para monitoramento de uso.
- **Connectivity**: connectivity_plus para detecção nativa de rede.
