import re

with open('lib/screens/planner_screen.dart', 'r') as f:
    content = f.read()

old_trailing = r"""trailing: selectedValue\.startsWith\('exercise:'\) \? Container\(.*?margin: const EdgeInsets\.only\(right: 8\),.*?child: Row\(.*?Text\("\$quantityValue".*?Text\(isCardio \? "min" : "sér".*?\].*?\).*?\) : null,"""

new_trailing = """trailing: selectedValue.startsWith('exercise:') ? Container(
        margin: const EdgeInsets.only(right: 8),
        width: 70,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: TextFormField(
                initialValue: quantityValue.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(bottom: 14), // tweak alignment
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
            Text(isCardio ? "min" : "sér", style: const TextStyle(color: Colors.white54, fontSize: 10)),
            const SizedBox(width: 8),
          ],
        ),
      ) : null,"""

content = re.sub(old_trailing, new_trailing, content, flags=re.DOTALL)

with open('lib/screens/planner_screen.dart', 'w') as f:
    f.write(content)
print("Patched quantity input")
