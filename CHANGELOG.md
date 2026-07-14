# Changelog

## [2.1.0+164] - 2026-07-14

### Adicionado
- **Suporte a Múltiplos Treinos Adiados:** Agora é possível ter várias sessões salvas temporariamente sem que uma sobreponha a outra. Cada uma aparece em um banner interativo com opções de retomar ou descartar na tela principal.
- **Sincronização Ativa Phone/Watch:** Adicionado suporte ao `HKHealthStore.startWatchApp` para abrir o aplicativo no Apple Watch de forma automática quando um treino é iniciado no iOS.
- **Estrutura WKExtensionDelegate no WatchOS:** Implementado o receptor nativo no relógio para processar as solicitações de abertura rápida vindas do celular.

### Corrigido
- **Reset Diário de Treinos Adiados:** Lógica implementada junto ao reset diário de dieta e água para limpar a lista de treinos adiados na virada do dia (meia-noite).
- **Problema de Atualização do WatchOS:** Corrigido o conflito onde as versões de compilação do Watch App ficavam estáticas e dessincronizadas em relação ao iOS, gerando falhas ao instalar atualizações via TestFlight/App Store.
- **Ajuste de Layout no Temporizador de Descanso:** Resolvido o problema de redimensionamento e overflow na tela cheia de descanso ativo.
