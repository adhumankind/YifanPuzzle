#!/usr/bin/env bash
# 用法: gen_images.sh <job名>...
# 每个后台任务负责几个 job，顺序执行；三个任务并行互不覆盖
set -uo pipefail
cd "$(dirname "$0")/.."
DRAW="C:\\Users\\adhum\\.zcode\\skills\\l0veyou-draw\\scripts\\draw.mjs"

prompt_for() {
  case "$1" in
    puzzle_01) echo "Vibrant flat cartoon storybook illustration of a spring landscape: rolling green hills covered in blooming pink cherry blossom trees, a winding sandy path, distant blue-purple mountains, bright gradient sky from light blue at top to soft pink near horizon, fluffy white clouds, cheerful saturated colors, clean shapes with subtle shading, distinct color regions, children's picture book art, no text, no watermark" ;;
    puzzle_02) echo "Vibrant flat cartoon storybook illustration of a summer lake: clear turquoise lake with a small wooden dock, lush green pine forest around the shore, a white sailboat, bright gradient sky from deep blue to light cyan, white clouds, cheerful saturated colors, clean shapes, distinct color regions, no text, no watermark" ;;
    puzzle_03) echo "Vibrant flat cartoon storybook illustration of an autumn valley: red and orange maple trees covering rolling hills, a small stone bridge over a stream, falling leaves, golden gradient sky from amber to pale yellow, cheerful saturated colors, clean shapes, distinct color regions, no text, no watermark" ;;
    puzzle_04) echo "Vibrant flat cartoon storybook illustration of a winter scene: snowy hills with snow-covered pine trees, a cute snowman, a cozy wooden cabin with warm glowing windows, dusk gradient sky from deep purple-blue to soft lavender with early stars, clean shapes, distinct color regions, no text, no watermark" ;;
    puzzle_05) echo "Vibrant flat cartoon storybook illustration of a tropical sunset beach: golden sand, tall palm trees leaning over the water, gentle waves, a small sailing boat on the horizon, orange-pink-purple gradient sunset sky with a big warm sun, seagulls, cheerful saturated colors, clean shapes, distinct color regions, no text, no watermark" ;;
    puzzle_06) echo "Vibrant flat cartoon storybook illustration of morning tea terraces: layered green tea fields on mountainsides, soft morning mist between layers, one big old tree on a hilltop, pale blue gradient sky with rising sun glow, cheerful colors, clean shapes, distinct color regions, no text, no watermark" ;;
    puzzle_07) echo "Vibrant flat cartoon storybook illustration of a starry night forest: tall dark blue pine trees silhouettes, deep blue gradient night sky full of bright stars and a big glowing crescent moon, glowing fireflies, a small camping tent with warm yellow light, magical colors, clean shapes, distinct color regions, no text, no watermark" ;;
    puzzle_08) echo "Vibrant flat cartoon storybook illustration of a wildflower meadow: colorful red yellow purple flowers in green grass, one giant friendly oak tree, a rainbow arc, butterflies, bright blue gradient sky with white puffy clouds, cheerful saturated colors, clean shapes, distinct color regions, no text, no watermark" ;;
    puzzle_09) echo "Vibrant flat cartoon storybook illustration of a rainforest waterfall: tall waterfall into a turquoise pool, lush tropical plants and ferns, a colorful toucan on a branch, mist sparkles, bright sky gap with blue gradient at top, cheerful saturated colors, clean shapes, distinct color regions, no text, no watermark" ;;
    puzzle_10) echo "Vibrant flat cartoon storybook illustration of a golden countryside: wheat field in golden yellow, one big lone tree on a small hill, a red barn with white fence, late afternoon gradient sky from warm orange to soft blue, haystacks, cheerful saturated colors, clean shapes, distinct color regions, no text, no watermark" ;;
    icon)      echo "iOS app icon design, flat cartoon style, rounded square canvas fully filled, a single large jigsaw puzzle piece in the center whose inner picture shows a beautiful landscape with gradient blue sky, green trees and hills, vibrant saturated colors, clean bold vector look, soft drop shadow, no text, no letters, no watermark" ;;
    wood)      echo "Seamless texture of warm brown wooden planks, cartoon mobile game UI style, smooth wood grain, soft even lighting, top-down flat view, fills entire frame edge to edge, no text, no watermark" ;;
    felt)      echo "Seamless texture of dark teal green felt fabric surface, puzzle game table mat, subtle fine fabric noise, even lighting, top-down flat view, fills entire frame edge to edge, no text, no watermark" ;;
    *) echo "" ;;
  esac
}

ratio_for() {
  case "$1" in
    icon|wood|felt) echo "1:1" ;;
    *) echo "16:9" ;;
  esac
}

for job in "$@"; do
  echo "=== JOB $job start $(date +%T) ==="
  p="$(prompt_for "$job")"
  r="$(ratio_for "$job")"
  out="$(node "$DRAW" --prompt "$p" --aspect-ratio "$r" --wait 420 2>&1)"
  echo "$out" | tail -5
  line="$(echo "$out" | grep '^RESULT_JSON:' | tail -1)"
  if [ -n "$line" ]; then
    src="$(node -e 'try{const j=JSON.parse(process.argv[1]);process.stdout.write(j.savedPaths[0]||"")}catch(e){}' "${line#RESULT_JSON:")}"
    if [ -n "$src" ] && [ -f "$src" ]; then
      mv "$src" "generated_images/$job.jpg"
      echo "=== JOB $job OK -> generated_images/$job.jpg"
    else
      echo "=== JOB $job FAIL: no saved file"
    fi
  else
    echo "=== JOB $job FAIL: no RESULT_JSON"
  fi
done
echo "=== ALL DONE $(date +%T) ==="
