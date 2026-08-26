const fs = require('fs');

let content = fs.readFileSync('lib/screens/planner_screen.dart', 'utf8');

// Replace _buildContinuousListAgenda
const oldFuncRegex = /List<Widget> _buildContinuousListAgenda.*?return \[\n.*?\n      Row\([\s\S]*?\n      \),\n      const SizedBox\(height: 12\),[\s\S]*?\];\n  \}/;

const newFunc = `List<Widget> _buildContinuousListAgenda(BuildContext context,
      TrackerProvider provider, PlannerState state, Color accentColor) {
    
    final blocks = state.continuousBlocks;
    final flatList = provider.flatContinuousList;
    final currentIndex = state.settings.continuousListCurrentIndex;

    return [
      Row(
        children: [
          const Icon(Icons.format_list_numbered,
              color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          const Text(
            "Lista Contínua",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
            tooltip: "Importar de Dias Fixos",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              _showImportDialog(context, provider, 'continuous');
            },
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.add_box, color: accentColor, size: 22),
            tooltip: "Novo Bloco",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              provider.addContinuousBlock();
            },
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (blocks.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            "Nenhum bloco na lista. Crie blocos de treino (A, B, C...) que se repetirão em sequência.",
            style: TextStyle(
                color: Colors.white30,
                fontSize: 13,
                fontStyle: FontStyle.italic),
          ),
        )
      else
        ...blocks.asMap().entries.map((entry) {
          final blockIdx = entry.key;
          final block = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: Colors.white.withOpacity(0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: block.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onFieldSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              provider.renameContinuousBlock(block.id, val.trim());
                            }
                          },
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: blockIdx > 0 ? () {
                              provider.reorderContinuousBlocks(blockIdx, blockIdx - 1);
                            } : null,
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: blockIdx < blocks.length - 1 ? () {
                              provider.reorderContinuousBlocks(blockIdx, blockIdx + 1);
                            } : null,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              provider.removeContinuousBlock(block.id);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (block.routineIds.isEmpty)
                    const Text("Nenhum treino neste bloco.", style: TextStyle(color: Colors.white30, fontSize: 12))
                  else
                    ...block.routineIds.asMap().entries.map((rEntry) {
                      final rIdx = rEntry.key;
                      final rawItem = rEntry.value;
                      
                      // Find flat index to check if it's the current workout
                      int flatIndex = 0;
                      for (int i = 0; i < blockIdx; i++) {
                        flatIndex += blocks[i].routineIds.length;
                      }
                      flatIndex += rIdx;
                      
                      final isCurrent = flatList.isNotEmpty && (flatIndex == (currentIndex % flatList.length));
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCurrent ? accentColor.withOpacity(0.1) : Colors.black12,
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrent ? Border.all(color: accentColor.withOpacity(0.5)) : null,
                        ),
                        child: Column(
                          children: [
                            if (isCurrent)
                              Align(
                                alignment: Alignment.topRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text("PRÓXIMO", style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            _buildBlockItemRow(context, provider, state, block.id, rIdx, rawItem, accentColor, block.routineIds.length),
                          ],
                        ),
                      );
                    }).toList(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: Icon(Icons.add, color: accentColor, size: 18),
                      label: Text("Adicionar Treino", style: TextStyle(color: accentColor)),
                      style: TextButton.styleFrom(
                        backgroundColor: accentColor.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        provider.addRoutineToContinuousBlock(block.id, '');
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
    ];
  }`;

// Remove old and add new
content = content.replace(oldFuncRegex, newFunc);

// Add _buildBlockItemRow (customized version of _buildPlannerItemRow for blocks)
const blockItemRow = `
  Widget _buildBlockItemRow(
    BuildContext context,
    TrackerProvider provider,
    PlannerState state,
    String blockId,
    int idx,
    String rawItem,
    Color accentColor,
    int blockLength,
  ) {
    final library = state.library;
    final routines = state.routines;

    String selectedValue = "";

    if (rawItem.startsWith('routine:')) {
      selectedValue = rawItem;
    } else if (rawItem.isNotEmpty) {
      // old format or generic, let's keep empty if unknown
      selectedValue = "";
    }

    final dropdownItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: "",
        child: Text("Selecione..."),
      ),
      if (routines.isNotEmpty) ...[
        const DropdownMenuItem(
          value: "_divider_routines",
          enabled: false,
          child: Text("— MODELOS DE TREINO —",
              style: TextStyle(
                  color: Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
        ...routines.map((r) => DropdownMenuItem(
              value: "routine:\${r.id}",
              child: Text(r.name),
            )),
      ],
    ];

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: dropdownItems.any((e) => e.value == selectedValue)
                    ? selectedValue
                    : "",
                isExpanded: true,
                dropdownColor: const Color(0xff1c1c1e),
                icon:
                    const Icon(Icons.arrow_drop_down, color: Colors.white54),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
                items: dropdownItems,
                onChanged: (val) {
                  if (val != null && !val.startsWith('_divider')) {
                    provider.updateRoutineInContinuousBlock(blockId, idx, val);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            InkWell(
              onTap: idx > 0 ? () => provider.reorderRoutinesInContinuousBlock(blockId, idx, idx - 1) : null,
              child: Icon(Icons.keyboard_arrow_up, color: idx > 0 ? Colors.white54 : Colors.transparent, size: 20),
            ),
            InkWell(
              onTap: idx < blockLength - 1 ? () => provider.reorderRoutinesInContinuousBlock(blockId, idx, idx + 1) : null,
              child: Icon(Icons.keyboard_arrow_down, color: idx < blockLength - 1 ? Colors.white54 : Colors.transparent, size: 20),
            ),
          ],
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.delete_outline,
              color: Colors.white54, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () {
            provider.removeRoutineFromContinuousBlock(blockId, idx);
          },
        ),
      ],
    );
  }
`;

content = content.replace('Widget _buildPlannerItemRow(', blockItemRow + '\n  Widget _buildPlannerItemRow(');

fs.writeFileSync('lib/screens/planner_screen.dart', content);
