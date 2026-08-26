const fs = require('fs');
let content = fs.readFileSync('lib/providers/tracker_provider.dart', 'utf8');

// Update _getDefaultState
content = content.replace(
  'history: [],\n      prs: {},',
  'continuousBlocks: [],\n      history: [],\n      prs: {},'
);

// Update state getter
content = content.replace(
  'planner: _workoutProvider!.planner,',
  'planner: _workoutProvider!.planner,\n      continuousBlocks: _workoutProvider!.continuousBlocks,'
);

// We need to inject continuousBlocks into WorkoutProvider on load
// Find _workoutProvider!.planner = loaded.planner;
const updateLoaded = `_workoutProvider!.planner = loaded.planner;
          _workoutProvider!.continuousBlocks = loaded.continuousBlocks;`;
content = content.replace('_workoutProvider!.planner = loaded.planner;', updateLoaded);

fs.writeFileSync('lib/providers/tracker_provider.dart', content);
