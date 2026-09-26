import fs from 'node:fs';
import path from 'node:path';

const ASSETS_DIR = path.resolve('YifanPuzzle/Resources/Assets.xcassets');
const APPICON_DIR = path.join(ASSETS_DIR, 'AppIcon.appiconset');

if (!fs.existsSync(APPICON_DIR)) {
  fs.mkdirSync(APPICON_DIR, { recursive: true });
}

const contentsJson = {
  "images": [
    {
      "idiom": "universal",
      "platform": "ios",
      "size": "1024x1024"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
};

fs.writeFileSync(path.join(APPICON_DIR, 'Contents.json'), JSON.stringify(contentsJson, null, 2));
console.log('AppIcon.appiconset created');
