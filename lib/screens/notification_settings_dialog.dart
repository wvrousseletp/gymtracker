import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_preferences.dart';
import '../models/profile.dart';
import '../providers/notification_provider.dart';
import '../providers/tracker_provider.dart';

void showNotificationSettingsDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const NotificationSettingsSheet(),
  );
}

class NotificationSettingsSheet extends StatelessWidget {
  const NotificationSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final prefs = provider.preferences;
    
    final tracker = context.watch<TrackerProvider>();
    final accentColor = _getAccentColor(tracker.currentProfile);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1e),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Notificações",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Hydration Settings
            _buildSectionHeader("ÁGUA 💧", accentColor),
            const SizedBox(height: 12),
            _buildHydrationSelector(context, prefs, provider, accentColor),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text("Silenciar à noite", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text(
                prefs.silenceHydrationAtNight 
                    ? "Não notificar entre ${prefs.silentNightStartHour}h e ${prefs.silentNightEndHour}h"
                    : "Desativado",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              value: prefs.silenceHydrationAtNight,
              activeColor: accentColor,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => provider.setSilenceHydrationAtNight(val),
            ),
            if (prefs.silenceHydrationAtNight) ...[
              const SizedBox(height: 8),
              _buildTimeSelector(
                context,
                "Horário de início",
                prefs.silentNightStartHour,
                accentColor,
                (time) => provider.setSilentNightStartHour(time),
              ),
              const SizedBox(height: 8),
              _buildTimeSelector(
                context,
                "Horário de fim",
                prefs.silentNightEndHour,
                accentColor,
                (time) => provider.setSilentNightEndHour(time),
              ),
            ],
            const SizedBox(height: 32),

            // Workout Settings
            _buildSectionHeader("TREINO 🏋️", accentColor),
            const SizedBox(height: 12),
            _buildRestTimerSelector(context, prefs, provider, accentColor),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text("Lembretes Motivacionais", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text("Avisar quando você ficar muitos dias sem treinar", style: TextStyle(color: Colors.white54, fontSize: 12)),
              value: prefs.motivationRemindersEnabled,
              activeColor: accentColor,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => provider.setMotivationRemindersEnabled(val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildHydrationSelector(BuildContext context, NotificationPreferences prefs, NotificationProvider provider, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Frequência de lembretes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              _buildRadio(
                title: "Agressiva (1h)",
                subtitle: "Lembrete a cada hora sem beber água.",
                value: HydrationAggressiveness.aggressive,
                groupValue: prefs.hydrationAggressiveness,
                color: accentColor,
                onChanged: (val) => provider.setHydrationAggressiveness(val!),
              ),
              _buildDivider(),
              _buildRadio(
                title: "Padrão (2h)",
                subtitle: "Lembrete a cada 2 horas (Recomendado).",
                value: HydrationAggressiveness.standard,
                groupValue: prefs.hydrationAggressiveness,
                color: accentColor,
                onChanged: (val) => provider.setHydrationAggressiveness(val!),
              ),
              _buildDivider(),
              _buildRadio(
                title: "Suave (4h)",
                subtitle: "Apenas 1 ou 2 alertas no dia se a meta estiver longe.",
                value: HydrationAggressiveness.relaxed,
                groupValue: prefs.hydrationAggressiveness,
                color: accentColor,
                onChanged: (val) => provider.setHydrationAggressiveness(val!),
              ),
              _buildDivider(),
              _buildRadio(
                title: "Desativada",
                subtitle: "Não me lembre de beber água.",
                value: HydrationAggressiveness.disabled,
                groupValue: prefs.hydrationAggressiveness,
                color: accentColor,
                onChanged: (val) => provider.setHydrationAggressiveness(val!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRestTimerSelector(BuildContext context, NotificationPreferences prefs, NotificationProvider provider, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Notificação de Descanso", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              _buildRadio(
                title: "Todas as Séries",
                subtitle: "Toca um som e exibe um banner a cada descanso finalizado.",
                value: RestTimerMode.all,
                groupValue: prefs.restTimerMode,
                color: accentColor,
                onChanged: (val) => provider.setRestTimerMode(val!),
              ),
              _buildDivider(),
              _buildRadio(
                title: "Apenas Ilha Dinâmica",
                subtitle: "Sem banner e sem barulho. O descanso continua aparecendo discretamente na Live Activity do iPhone.",
                value: RestTimerMode.liveActivityOnly,
                groupValue: prefs.restTimerMode,
                color: accentColor,
                onChanged: (val) => provider.setRestTimerMode(val!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRadio<T>({
    required String title,
    required String subtitle,
    required T value,
    required T groupValue,
    required Color color,
    required ValueChanged<T?> onChanged,
  }) {
    return RadioListTile<T>(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      value: value,
      groupValue: groupValue,
      activeColor: color,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onChanged: onChanged,
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.white.withOpacity(0.1), indent: 16, endIndent: 16);
  }

  Widget _buildTimeSelector(
    BuildContext context,
    String label,
    String currentHour,
    Color accentColor,
    Function(String) onTimeChanged,
  ) {
    return InkWell(
      onTap: () async {
        final selected = await _showTimePickerDialog(context, currentHour, accentColor);
        if (selected != null) {
          onTimeChanged(selected);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                Text(
                  "${currentHour}h",
                  style: TextStyle(color: accentColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showTimePickerDialog(
    BuildContext context,
    String currentHour,
    Color accentColor,
  ) async {
    int initialHour = int.tryParse(currentHour) ?? 22;
    
    return showDialog<String>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: const Color(0xff1c1c1e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Selecione a hora",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 50,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    initialHour = index;
                  },
                  controller: FixedExtentScrollController(initialItem: initialHour),
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      final isSelected = index == initialHour;
                      return Center(
                        child: Text(
                          "${index.toString().padLeft(2, '0')}h",
                          style: TextStyle(
                            color: isSelected ? accentColor : Colors.white54,
                            fontSize: isSelected ? 24 : 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                    childCount: 24,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text("Cancelar", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx, initialHour.toString().padLeft(2, '0')),
                    style: TextButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.black),
                    child: const Text("Confirmar", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAccentColor(Profile profile) {
    switch (profile.colorAccent) {
      case 'Vermelho': return const Color(0xffFF3B30);
      case 'Azul': return const Color(0xff0A84FF);
      case 'Verde': return const Color(0xff30D158);
      case 'Amarelo': return const Color(0xffFFD60A);
      case 'Laranja': return const Color(0xffFF9F0A);
      case 'Rosa': return const Color(0xffFF375F);
      case 'Roxo': return const Color(0xffBF5AF2);
      default: return Colors.white;
    }
  }
}
