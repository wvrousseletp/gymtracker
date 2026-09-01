import re

with open('lib/screens/planner_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("import '../models/exercise.dart';\n", "")

with open('lib/screens/planner_screen.dart', 'w') as f:
    f.write(content)

with open('lib/widgets/premium_strength_set_card.dart', 'r') as f:
    content = f.read()

content = re.sub(r'if \(isRight\) _isRunningRight = false;\n\s*else _isRunningLeft = false;', 'if (isRight) { _isRunningRight = false; }\n        else { _isRunningLeft = false; }', content)
content = re.sub(r'if \(isRight\) _isRunningRight = true;\n\s*else _isRunningLeft = true;', 'if (isRight) { _isRunningRight = true; }\n        else { _isRunningLeft = true; }', content)
content = re.sub(r'if \(isRight\) _elapsedRight = 0;\n\s*else _elapsedLeft = 0;', 'if (isRight) { _elapsedRight = 0; }\n        else { _elapsedLeft = 0; }', content)

# Check for line 105:
content = re.sub(r'if \(isRight\) _timerRight\?\.cancel\(\);\n\s*else _timerLeft\?\.cancel\(\);', 'if (isRight) { _timerRight?.cancel(); }\n        else { _timerLeft?.cancel(); }', content)

with open('lib/widgets/premium_strength_set_card.dart', 'w') as f:
    f.write(content)
