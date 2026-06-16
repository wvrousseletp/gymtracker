import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tracker_provider.dart';
import '../models/exercise.dart';
import '../widgets/glass_card.dart';
import '../widgets/profile_avatar.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({Key? key}) : super(key: key);

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final List<String> _daysOfWeek = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];

  String _getDayNamePt(String day) {
    switch (day) {
      case 'seg': return 'Segunda-feira';
      case 'ter': return 'Terça-feira';
      case 'qua': return 'Quarta-feira';
      case 'qui': return 'Quinta-feira';
      case 'sex': return 'Sexta-feira';
      case 'sab': return 'Sábado';
      case 'dom': return 'Domingo';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackerProvider>(context);
    final state = provider.state;

    if (state == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final accentColor = ThemeUtils.getColor(provider.currentProfile.colorAccent);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _daysOfWeek.length,
        itemBuilder: (context, index) {
          final day = _daysOfWeek[index];
          final items = state.planner[day] ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: Colors.white.withOpacity(0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho do dia
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getDayNamePt(day),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_box_outlined, color: accentColor, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          provider.addPlannerItem(day);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "Nenhum treino agendado",
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, idx) {
                        final rawItem = items[idx];
                        return _buildPlannerItemRow(context, provider, day, idx, rawItem, accentColor);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlannerItemRow(
    BuildContext context,
    TrackerProvider provider,
    String day,
    int idx,
    String rawItem,
    Color accentColor,
  ) {
    final state = provider.state!;
    final library = state.library;
    final routines = state.routines;

    // Decodificar valor selecionado e quantidade
    String selectedValue = ""; // "routine:preset-a" ou "exercise:lib-14"
    int quantityValue = 3;     // séries ou minutos

    if (rawItem.startsWith('routine:')) {
      selectedValue = rawItem;
    } else if (rawItem.startsWith('exercise:')) {
      final parts = rawItem.split(':');
      if (parts.length >= 3) {
        selectedValue = "${parts[0]}:${parts[1]}";
        quantityValue = int.tryParse(parts[2]) ?? 3;
      } else {
        selectedValue = rawItem;
      }
    } else if (rawItem.isNotEmpty) {
      selectedValue = "routine:$rawItem";
    }

    // Identificar se é cardio
    bool isCardio = false;
    if (selectedValue.startsWith('exercise:')) {
      final exId = selectedValue.substring(9);
      final libEx = library.where((e) => e.id == exId).firstOrNull;
      if (libEx != null && libEx.muscle.toLowerCase().contains('cardio')) {
        isCardio = true;
      }
    }

    // Ordenar biblioteca de exercícios (corrigindo bug de desorganização)
    final sortedLibrary = List<LibraryExercise>.from(library)
      ..sort((a, b) {
        final muscleComp = a.muscle.toLowerCase().compareTo(b.muscle.toLowerCase());
        if (muscleComp != 0) return muscleComp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Dropdown de Seleção de Item
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedValue.isEmpty ? null : selectedValue,
                  hint: const Text(
                    "Selecione o Item",
                    style: TextStyle(color: Colors.white30, fontSize: 13),
                  ),
                  dropdownColor: const Color(0xff1c1c1e),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  isExpanded: true,
                  onChanged: (val) {
                    if (val == null) return;
                    if (val.startsWith('exercise:')) {
                      final exId = val.substring(9);
                      final libEx = library.where((e) => e.id == exId).firstOrNull;
                      final checkCardio = libEx != null && libEx.muscle.toLowerCase().contains('cardio');
                      if (checkCardio) {
                        provider.updatePlannerItem(day, idx, "$val:30"); // Default 30 min
                      } else {
                        provider.updatePlannerItem(day, idx, "$val:3");  // Default 3 sets
                      }
                    } else {
                      provider.updatePlannerItem(day, idx, val);
                    }
                  },
                  items: [
                    // Categoria Rotinas
                    const DropdownMenuItem<String>(
                      enabled: false,
                      value: "title:routines",
                      child: Text(
                        "--- Blocos de Treino (Rotinas) ---",
                        style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    ...routines.map((r) => DropdownMenuItem<String>(
                      value: "routine:${r.id}",
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(r.name),
                      ),
                    )),
                    // Categoria Exercícios Avulsos
                    const DropdownMenuItem<String>(
                      enabled: false,
                      value: "title:exercises",
                      child: Text(
                        "--- Exercícios Avulsos ---",
                        style: TextStyle(color: Colors.white30, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    ...sortedLibrary.map((ex) => DropdownMenuItem<String>(
                      value: "exercise:${ex.id}",
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text("${ex.name} (${ex.muscle})"),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Seletor de Quantidade (séries ou min para exercícios avulsos)
          if (selectedValue.startsWith('exercise:')) ...[
            Container(
              width: 50,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: TextFormField(
                initialValue: quantityValue.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                onChanged: (val) {
                  int quantity = int.tryParse(val) ?? (isCardio ? 30 : 3);
                  if (quantity < 1) quantity = 1;
                  
                  final parts = rawItem.split(':');
                  if (parts.length >= 2) {
                    provider.updatePlannerItem(day, idx, "${parts[0]}:${parts[1]}:$quantity");
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            Text(
              isCardio ? 'min' : 'sér',
              style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
          ],

          // Botões Reordenar (▲)
          GestureDetector(
            onTap: idx == 0
                ? null
                : () {
                    provider.reorderPlannerItem(day, idx, true);
                  },
            child: Opacity(
              opacity: idx == 0 ? 0.3 : 1.0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Text('▲', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Botões Reordenar (▼)
          GestureDetector(
            onTap: idx == (provider.state!.planner[day]!.length - 1)
                ? null
                : () {
                    provider.reorderPlannerItem(day, idx, false);
                  },
            child: Opacity(
              opacity: idx == (provider.state!.planner[day]!.length - 1) ? 0.3 : 1.0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: const Text('▼', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Botão Remover
          GestureDetector(
            onTap: () {
              provider.removePlannerItem(day, idx);
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
