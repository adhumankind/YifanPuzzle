import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';

const DRAW_SCRIPT = 'C:\\Users\\adhum\\.zcode\\skills\\l0veyou-draw\\scripts\\draw.mjs';
const OUT_DIR = path.resolve('generated_images');
if (!fs.existsSync(OUT_DIR)) {
  fs.mkdirSync(OUT_DIR, { recursive: true });
}

const TASKS = [
  {
    name: 'puzzle_01',
    aspectRatio: '16:9',
    prompt: 'Vibrant flat cartoon storybook illustration of a spring mountain landscape: rolling green hills covered in blooming pink cherry blossom trees, winding stone path, distant soft blue mountains, radiant sky gradient from azure to soft warm peach near horizon, white fluffy clouds, clean silhouettes, distinct recognizable color zones, rich saturated palette, mobile jigsaw puzzle art, no text, no watermark'
  },
  {
    name: 'puzzle_02',
    aspectRatio: '16:9',
    prompt: 'Vibrant flat cartoon storybook illustration of a tranquil summer lake: crystal turquoise alpine lake with small wooden dock, dense evergreen pine trees surrounding shores, white small sailboat, vivid sky gradient from deep cobalt to bright cyan, sunshine rays, clean outlines, high contrast color patches, children book art, no text, no watermark'
  },
  {
    name: 'puzzle_03',
    aspectRatio: '16:9',
    prompt: 'Vibrant flat cartoon storybook illustration of an autumn maple valley: rolling hills carpeted in fiery scarlet and amber maple trees, rustic arched stone bridge over bubbling brook, falling leaves, luminous sky gradient from golden yellow to soft cream, distinct color fields, cheerful aesthetic, no text, no watermark'
  },
  {
    name: 'puzzle_04',
    aspectRatio: '16:9',
    prompt: 'Vibrant flat cartoon storybook illustration of a peaceful winter forest: snowy hills dotted with snow-laden pine trees, cute friendly snowman with red scarf, cozy log cabin with glowing warm yellow windows, enchanting dusk sky gradient from deep indigo to soft lilac, twinkling stars, crisp shapes, no text, no watermark'
  },
  {
    name: 'puzzle_05',
    aspectRatio: '16:9',
    prompt: 'Vibrant flat cartoon storybook illustration of a tropical ocean sunset: curved coconut palm trees over powdery sand beach, gentle turquoise ocean waves, little sailboat far away, brilliant sunset sky gradient from fiery crimson to golden amber, seagulls, bold distinct color regions, sunny vacation vibe, no text, no watermark'
  },
  {
    name: 'puzzle_06',
    aspectRatio: '16:9',
    prompt: 'Vibrant flat cartoon storybook illustration of morning mountain tea terraces: stepped green hillside tea plantations, gentle soft morning mist, majestic solitary ancient tree on high peak, morning dawn sky gradient from pastel violet to pale sunlit yellow, clear shapes, beautiful layered depth, no text, no watermark'
  },
  {
    name: 'puzzle_07',
    aspectRatio: '16:9',
    prompt: 'Vibrant flat cartoon storybook illustration of a starry night camping forest: dark pine trees silhouette against magical night sky, radiant sky gradient from midnight navy to deep purple, huge glowing golden crescent moon, glowing green fireflies, warm yellow illuminated tent, clear contrasts, cozy atmosphere, no text, no watermark'
  },
  {
    name: 'puzzle_08',
    aspectRatio: '16:9',
    prompt: 'Vibrant flat cartoon storybook illustration of a blooming wildflower meadow: colorful field of red poppies, yellow sunflowers, purple lavender, giant friendly oak tree in center, rainbow across bright sky gradient from sky blue to airy turquoise, butterflies, cheerful vibrant colors, no text, no watermark'
  },
  {
    name: 'puzzle_09',
    aspectRatio: '16:9',
    prompt: 'Vibrant flat cartoon storybook illustration of an exotic rainforest waterfall: dramatic crystal waterfall pouring into emerald lagoon, lush tropical banana leaves and giant ferns, colorful toucan perched on branch, sunbeams through misty canopy, sky gap with brilliant cyan gradient, vibrant tones, no text, no watermark'
  },
  {
    name: 'puzzle_10',
    aspectRatio: '16:9',
    prompt: 'Vibrant flat cartoon storybook illustration of golden harvest countryside: rolling golden wheat fields, classic red wooden barn with white trim, big solitary willow tree on grassy knoll, windmill, late afternoon sky gradient from rich orange to warm blue, distinct colorful blocks, peaceful rural charm, no text, no watermark'
  },
  {
    name: 'icon',
    aspectRatio: '1:1',
    prompt: 'Mobile app icon, flat modern vector cartoon design, rounded square framing, centered large jigsaw puzzle piece, inside the puzzle piece is a miniature scenic landscape of gradient blue sky, green hill and a cartoon tree, vibrant clean colors, subtle soft depth, glossy border, professional iOS icon style, no text, no letters, no watermark'
  },
  {
    name: 'wood_texture',
    aspectRatio: '1:1',
    prompt: 'Seamless texture of warm natural polished wooden tabletop planks, top-down flat perspective, subtle light wood grain, warm honey caramel tones, soft matte game board table surface, full frame coverage edge to edge, no text, no watermark'
  },
  {
    name: 'felt_texture',
    aspectRatio: '1:1',
    prompt: 'Seamless texture of premium dark teal green felt fabric, puzzle table mat cloth, subtle fine fabric weave, perfectly even flat top-down lighting, full frame coverage edge to edge, clean soft texture, no text, no watermark'
  }
];

function runDraw(task) {
  return new Promise((resolve) => {
    console.log(`\n▶️ 开始生成: ${task.name} (${task.aspectRatio})`);
    const args = [
      DRAW_SCRIPT,
      '--prompt', task.prompt,
      '--aspect-ratio', task.aspectRatio,
      '--wait', '420'
    ];
    const proc = spawn('node', args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (d) => {
      const s = d.toString();
      stdout += s;
      process.stdout.write(s);
    });

    proc.stderr.on('data', (d) => {
      const s = d.toString();
      stderr += s;
      process.stderr.write(s);
    });

    proc.on('close', (code) => {
      let savedPath = null;
      const match = stdout.match(/RESULT_JSON:(.*)/);
      if (match) {
        try {
          const res = JSON.parse(match[1]);
          if (res.savedPaths && res.savedPaths.length > 0) {
            savedPath = res.savedPaths[0];
          }
        } catch (e) {
          console.error(`解析 JSON 失败: ${e.message}`);
        }
      }

      if (code === 0 && savedPath && fs.existsSync(savedPath)) {
        const ext = path.extname(savedPath) || '.png';
        const targetPath = path.join(OUT_DIR, `${task.name}${ext}`);
        fs.copyFileSync(savedPath, targetPath);
        console.log(`✅ ${task.name} 保存成功: ${targetPath}`);
        resolve({ name: task.name, success: true, path: targetPath });
      } else {
        console.error(`❌ ${task.name} 生成失败 (退出码: ${code})`);
        resolve({ name: task.name, success: false });
      }
    });
  });
}

async function main() {
  console.log(`🎨 准备顺序生成 ${TASKS.length} 个素材...`);
  const results = [];
  for (const t of TASKS) {
    const extPng = path.join(OUT_DIR, `${t.name}.png`);
    const extJpg = path.join(OUT_DIR, `${t.name}.jpg`);
    if (fs.existsSync(extPng) || fs.existsSync(extJpg)) {
      console.log(`⏩ 发现已存在素材 ${t.name}，跳过`);
      results.push({ name: t.name, success: true });
      continue;
    }
    const res = await runDraw(t);
    results.push(res);
    // 间隔 3 秒，避免过度高频
    await new Promise((r) => setTimeout(r, 3000));
  }
  console.log('\n📊 全部任务结束，结果汇总:');
  console.table(results);
}

main().catch(err => {
  console.error('全局异常:', err);
  process.exit(1);
});
