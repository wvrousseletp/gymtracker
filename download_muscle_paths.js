const fs = require('fs');

async function run() {
  const frontRes = await fetch("https://raw.githubusercontent.com/HichamELBSI/react-native-body-highlighter/main/assets/bodyFront.ts");
  const backRes = await fetch("https://raw.githubusercontent.com/HichamELBSI/react-native-body-highlighter/main/assets/bodyBack.ts");
  
  const frontText = await frontRes.text();
  const backText = await backRes.text();
  
  fs.writeFileSync('front.ts', frontText);
  fs.writeFileSync('back.ts', backText);
}
run();
