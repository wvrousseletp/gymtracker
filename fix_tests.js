const fs = require('fs');

const test1 = 'test/models/planner_state_json_test.dart';
if (fs.existsSync(test1)) {
  let content = fs.readFileSync(test1, 'utf8');
  content = content.replace(/history: \[\]/g, 'continuousBlocks: [],\nhistory: []');
  fs.writeFileSync(test1, content);
}

const test2 = 'test/models/planner_state_test.dart';
if (fs.existsSync(test2)) {
  let content = fs.readFileSync(test2, 'utf8');
  content = content.replace(/history: \[\]/g, 'continuousBlocks: [],\nhistory: []');
  fs.writeFileSync(test2, content);
}
