#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
site_dir="${script_dir:h}"
media_dir="$site_dir/media"
work_dir="$(mktemp -d -t hesba-video)"
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$media_dir" "$work_dir/slides"
python3 "$script_dir/create_slides.py" "$work_dir/slides"

narration=(
  "لسه بتدير حسابات محلك بين الدفاتر وأكتر من تطبيق؟ مع حِسبة، كل شغلك بقى في مكان واحد."
  "تابع رصيد الخزنة، والمحافظ، وماكينات الشحن، وتحصيلات المندوبين، لحظة بلحظة."
  "وكمان حسابات فوري والشركات، من الرصيد والشحن، لحد العمولات وسجل كل حساب."
  "ومن الموبايل، تقدر تتابع شغلك على أندرويد وآي أو إس، بنفس الحساب، ونفس الصلاحيات."
  "حِسبة بيسجّل كل حركة، وبيساعدك تراجع التقارير، وتدير الموظفين والمخزون، بشكل أسرع وأوضح."
  "حِسبة. كل جنيه في حسابه. جرّب النظام دلوقتي، وتواصل معانا من خلال الموقع."
)

captions=(
  "لسه بتدير حسابات محلك بين الدفاتر وأكتر من تطبيق؟\nمع حِسبة، كل شغلك بقى في مكان واحد."
  "تابع رصيد الخزنة والمحافظ وماكينات الشحن\nوتحصيلات المندوبين لحظة بلحظة."
  "حسابات فوري والشركات: الرصيد والشحن\nوالعمولات وسجل واضح لكل حساب."
  "تابع شغلك على Android وiOS\nبنفس الحساب ونفس الصلاحيات."
  "سجّل كل حركة وراجع التقارير\nوأدر الموظفين والمخزون بشكل أوضح."
  "حِسبة — كل جنيه في حسابه.\nجرّب النظام وتواصل معنا من خلال الموقع."
)

caption_timing="$work_dir/caption-timing.tsv"
: > "$caption_timing"

for index in {1..6}; do
  audio_file="$work_dir/voice-${index}.aiff"
  segment_file="$work_dir/segment-${index}.mp4"
  slide_file="$work_dir/slides/slide-0${index}.png"

  say -v Majed -r 168 -o "$audio_file" "${narration[$index]}"
  voice_duration="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$audio_file")"
  scene_duration="$(python3 -c "print(round(float('$voice_duration') + 0.9, 3))")"
  fade_out="$(python3 -c "print(max(round(float('$scene_duration') - 0.35, 3), 0))")"
  printf '%s\t%s\t%s\n' "$index" "$scene_duration" "${captions[$index]}" >> "$caption_timing"

  ffmpeg -hide_banner -loglevel error -y \
    -loop 1 -framerate 30 -i "$slide_file" \
    -i "$audio_file" \
    -filter_complex "[0:v]scale=1920:1080,zoompan=z='min(zoom+0.00018,1.022)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1920x1080:fps=30,fade=t=in:st=0:d=0.3,fade=t=out:st=${fade_out}:d=0.35[v];[1:a]aresample=48000,adelay=250:all=1,apad=pad_dur=0.65[a]" \
    -map "[v]" -map "[a]" -t "$scene_duration" \
    -c:v libx264 -preset medium -crf 21 -pix_fmt yuv420p \
    -c:a aac -b:a 160k -ar 48000 -movflags +faststart "$segment_file"
done

for segment in "$work_dir"/segment-*.mp4; do
  printf "file '%s'\n" "$segment"
done > "$work_dir/segments.txt"

ffmpeg -hide_banner -loglevel error -y \
  -f concat -safe 0 -i "$work_dir/segments.txt" \
  -c copy -movflags +faststart "$media_dir/hesba-system-intro.mp4"

ffmpeg -hide_banner -loglevel error -y \
  -i "$work_dir/slides/slide-01.png" -frames:v 1 -q:v 2 \
  "$media_dir/hesba-system-poster.jpg"

python3 "$script_dir/create_captions.py" "$caption_timing" "$media_dir/hesba-system-intro-ar.vtt"

echo "Created: $media_dir/hesba-system-intro.mp4"
echo "Created: $media_dir/hesba-system-poster.jpg"
echo "Created: $media_dir/hesba-system-intro-ar.vtt"
