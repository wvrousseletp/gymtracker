const fs = require('fs');
let content = fs.readFileSync('lib/screens/planner_screen.dart', 'utf8');

content = content.replace('final routines = state.routines;', 'final library = state.library;\n    final routines = state.routines;');

fs.writeFileSync('lib/screens/planner_screen.dart', content);
