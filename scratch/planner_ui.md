# Modern Planner UI

We will create a rich `GestureDetector` card that replaces the `DropdownButton`.

```dart
Widget _buildModernPlannerCard({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
  VoidCallback? onStart,
  VoidCallback? onDelete,
  Widget? trailing,
}) {
  return Dismissible(
    key: UniqueKey(),
    direction: DismissibleDirection.endToStart,
    onDismissed: (_) => onDelete?.call(),
    background: Container(
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(right: 20),
      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
      child: Icon(Icons.delete, color: Colors.white),
    ),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (onStart != null) ...[
              SizedBox(width: 8),
              GestureDetector(
                onTap: onStart,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text("COMEÇAR", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
```
