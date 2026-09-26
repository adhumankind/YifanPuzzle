import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const DRAW_SCRIPT = 'C:\\Users\\adhum\\.zcode\\skills\\l0veyou-draw\\scripts\\draw.mjs';
const OUT_DIR = path.resolve('generated_images/elements');
if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

// 纯单色纯白底背景提示词，便于像素级无损抠图生成真正的 RGBA 透明 PNG
const TASKS = [
  {
    name: 'puzzle_piece_gold',
    prompt: 'One single 3D glossy metallic gold jigsaw puzzle piece, angled dynamic view, sharp beveled edges, isolated on pure solid white background, high contrast, clean vector render, no shadows, no watermark'
  },
  {
    name: 'trophy_3d',
    prompt: 'A shiny cartoon gold championship trophy cup with star emblem, 3D mobile game icon style, isolated on pure solid white background, vibrant colors, clean outlines, no shadows, no watermark'
  },
  {
    name: 'magnifier_tool',
    prompt: 'A cute cartoon magnifying glass puzzle helper tool, wooden handle, crystal glass lens, isolated on pure solid white background, game UI asset, no shadows, no watermark'
  }
];

function runDraw(task) {
  return new Promise((resolve) => {
    console.log(`\n▶️ 开始生成元素素材: ${task.name}`);
    const args = [
      DRAW_SCRIPT,
      '--prompt', task.prompt,
      '--aspect-ratio', '1:1',
      '--wait', '420'
    ];
    const proc = spawn('node', args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '';
    proc.stdout.on('data', d => stdout += d.toString());
    proc.on('close', code => {
      let savedPath = null;
      const match = stdout.match(/RESULT_JSON:(.*)/);
      if (match) {
        try {
          const res = JSON.parse(match[1]);
          if (res.savedPaths && res.savedPaths.length > 0) savedPath = res.savedPaths[0];
        } catch (e) {}
      }
      if (code === 0 && savedPath && fs.existsSync(savedPath)) {
        const targetPath = path.join(OUT_DIR, `${task.name}.png`);
        fs.copyFileSync(savedPath, targetPath);
        console.log(`✅ ${task.name} 下载成功: ${targetPath}`);
        resolve({ name: task.name, path: targetPath });
      } else {
        console.error(`❌ ${task.name} 失败`);
        resolve(null);
      }
    });
  });
}

async function main() {
  for (const t of TASKS) {
    await runDraw(t);
  }
}

main();
