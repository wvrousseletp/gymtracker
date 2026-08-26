const fs = require('fs');

// 1. Fix planner_screen.dart (library variable)
let pScreen = fs.readFileSync('lib/screens/planner_screen.dart', 'utf8');

// The original _buildPlannerItemRow had this:
// final library = state.library;
// final routines = state.routines;

pScreen = pScreen.replace(/Widget _buildPlannerItemRow\([\s\S]*?final routines = state.routines;/g, match => {
    if (!match.includes('final library')) {
        return match.replace('final routines = state.routines;', 'final library = state.library;\n    final routines = state.routines;');
    }
    return match;
});

pScreen = pScreen.replace(/Widget _buildBlockItemRow\([\s\S]*?final library = state.library;\n    final routines = state.routines;/g, match => {
    return match.replace('final library = state.library;\n    final routines = state.routines;', 'final routines = state.routines;');
});

fs.writeFileSync('lib/screens/planner_screen.dart', pScreen);


// 2. Fix tests
function fixTest(path) {
    if (!fs.existsSync(path)) return;
    let txt = fs.readFileSync(path, 'utf8');
    txt = txt.replace(/PlannerState\s*\(\s*library:/g, 'PlannerState( continuousBlocks: [], library:');
    fs.writeFileSync(path, txt);
}
fixTest('test/models/planner_state_json_test.dart');
fixTest('test/models/planner_state_test.dart');

