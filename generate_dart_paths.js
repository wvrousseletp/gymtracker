const fs = require('fs');

function parseTS(fileContent) {
    let result = [];
    const regex = /slug:\s*"([^"]+)",[^}]*?path:\s*\{([^}]*)\}/gs;
    let match;
    while ((match = regex.exec(fileContent)) !== null) {
        const slug = match[1];
        const pathBlock = match[2];
        const paths = [];
        const pathRegex = /"(M[^"]+)"/g;
        let pathMatch;
        while ((pathMatch = pathRegex.exec(pathBlock)) !== null) {
            paths.push(pathMatch[1]);
        }
        result.push({slug, paths});
    }
    return result;
}

const frontContent = fs.readFileSync('front.ts', 'utf8');
const backContent = fs.readFileSync('back.ts', 'utf8');

const frontData = parseTS(frontContent);
const backData = parseTS(backContent);

let dartCode = `import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

class MusclePathData {
  final String slug;
  final List<Path> paths;
  MusclePathData({required this.slug, required this.paths});
}

class AnatomyPaths {
  static final List<MusclePathData> front = [
`;

for (let d of frontData) {
    dartCode += `    MusclePathData(slug: "${d.slug}", paths: [\n`;
    for (let p of d.paths) {
        dartCode += `      parseSvgPathData("${p}"),\n`;
    }
    dartCode += `    ]),\n`;
}
dartCode += `  ];\n\n  static final List<MusclePathData> back = [\n`;
for (let d of backData) {
    dartCode += `    MusclePathData(slug: "${d.slug}", paths: [\n`;
    for (let p of d.paths) {
        dartCode += `      parseSvgPathData("${p}"),\n`;
    }
    dartCode += `    ]),\n`;
}
dartCode += `  ];\n}\n`;

fs.writeFileSync('lib/widgets/analytics/anatomy_paths.dart', dartCode);
