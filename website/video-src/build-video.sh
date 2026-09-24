#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
site_dir="${script_dir:h}"
media_dir="$site_dir/media"
work_dir="$(mktemp -d -t hesba-video)"
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$media_dir" "$work_dir/slides"
python3 "$script_dir/create_slides.py" "$work_dir/slides"

# Egyptian Arabic neural voice. Install the pinned dependency from
# requirements-video.txt before rebuilding the video.
edge_tts_bin="${EDGE_TTS_BIN:-$(command -v edge-tts || true)}"
if [[ -z "$edge_tts_bin" ]]; then
  echo "edge-tts is required. Run: python3 -m pip install -r '$script_dir/requirements-video.txt'" >&2
  exit 1
fi

narration=(
  "لِسَّه بتراجع شغل المحل في كذا دفتر وكذا تطبيق؟ حِسْبَة بتجمع لك حركة الفلوس كلها في نظام واحد، واضح وسهل."
  "شوف رصيد الخزنة والمحافظ وماكينات الدفع، وسجّل تحصيلات المندوبين أول بأول، من غير حسابات متفرقة."
  "كل حساب له رصيد وسجل حركات واضح: شحن، وسحب، وعمولة، وتحويل. وفي نهاية اليوم، الرصيد بيترحّل تلقائي لليوم الجديد."
  "ومن اَلْمُوبَايْل أو اَلْكُمْبِيُوتَر، المدير والموظفين بيشتغلوا على نفس البيانات، وكل واحد بالصلاحيات اللي تحددها له."
  "تابع المخزون والمبيعات، ورَاجِع التَّقَارِير وسِجِلّ العَمَلِيَّات. وكل حركة مُسَجَّلَة في النِّظَام، علشان المراجعة تبقى أسرع وأدق."
  "نِظَام حِسْبَه بِيخَلِّيك تِعْرَف كُلّ جُنَيْه رَاح فِين، وَدَخَل مِنِين. اطلب عرض مجاني، وابدأ تنظّم حسابات محلك من أول يوم."
)

captions=(
  "لسه بتراجع شغل المحل في كذا دفتر وكذا تطبيق؟\nحِسْبَة بتجمع لك حركة الفلوس كلها في نظام واحد، واضح وسهل."
  "شوف رصيد الخزنة والمحافظ وماكينات الدفع،\nوسجّل تحصيلات المندوبين أول بأول، من غير حسابات متفرقة."
  "كل حساب له رصيد وسجل حركات واضح: شحن، وسحب، وعمولة، وتحويل.\nوفي نهاية اليوم، الرصيد بيترحّل تلقائي لليوم الجديد."
  "من الموبايل أو الكمبيوتر، المدير والموظفين بيشتغلوا على نفس البيانات،\nوكل واحد بالصلاحيات اللي تحددها له."
  "تابع المخزون والمبيعات، وراجع التقارير وسجل العمليات.\nوكل حركة مسجّلة في النظام، علشان المراجعة تبقى أسرع وأدق."
  "نظام حِسبة بيخلّيك تعرف كل جنيه راح فين، ودخل منين.\nاطلب عرض مجاني، وابدأ تنظّم حسابات محلك من أول يوم."
)

caption_timing="$work_dir/caption-timing.tsv"
: > "$caption_timing"

for index in {1..6}; do
  raw_audio_file="$work_dir/voice-${index}.mp3"
  audio_file="$work_dir/voice-${index}.wav"
  segment_file="$work_dir/segment-${index}.mp4"
  slide_file="$work_dir/slides/slide-0${index}.png"

  "$edge_tts_bin" \
    --voice ar-EG-ShakirNeural \
    --rate=+7% \
    --pitch=-2Hz \
    --text "${narration[$index]}" \
    --write-media "$raw_audio_file"

  # Keep every scene equally clear and broadcast-ready without clipping.
  ffmpeg -hide_banner -loglevel error -y \
    -i "$raw_audio_file" \
    -af "highpass=f=75,lowpass=f=14500,acompressor=threshold=-18dB:ratio=2.4:attack=8:release=90:makeup=2,loudnorm=I=-16:TP=-1.5:LRA=7" \
    -ar 48000 -ac 1 "$audio_file"

  voice_duration="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$audio_file")"
  scene_duration="$(python3 -c "print(round(float('$voice_duration') + 0.75, 3))")"
  fade_out="$(python3 -c "print(max(round(float('$scene_duration') - 0.35, 3), 0))")"
  printf '%s\t%s\t%s\n' "$index" "$scene_duration" "${captions[$index]}" >> "$caption_timing"

  if [[ "$index" == "1" ]]; then
    # Open with motion instead of holding on a static logo for the full first
    # narration: logo reveal, rapid product montage, then a clean brand lockup.
    transition=0.28
    logo_open=1.8
    dashboard_shot=2.8
    accounts_shot=2.6
    control_shot=2.3
    read offset_1 offset_2 offset_3 offset_4 logo_close <<< "$(python3 -c "
t=$transition
d1=$logo_open; d2=$dashboard_shot; d3=$accounts_shot; d4=$control_shot
o1=d1-t; o2=d1+d2-2*t; o3=d1+d2+d3-3*t; o4=d1+d2+d3+d4-4*t
print(*(round(v, 3) for v in (o1, o2, o3, o4, float('$scene_duration')-o4)))
")"

    ffmpeg -hide_banner -loglevel error -y \
      -loop 1 -framerate 30 -i "$work_dir/slides/slide-01.png" \
      -loop 1 -framerate 30 -i "$work_dir/slides/slide-02.png" \
      -loop 1 -framerate 30 -i "$work_dir/slides/slide-03.png" \
      -loop 1 -framerate 30 -i "$work_dir/slides/slide-05.png" \
      -loop 1 -framerate 30 -i "$work_dir/slides/slide-01.png" \
      -i "$audio_file" \
      -filter_complex "
        [0:v]scale=1920:1080,zoompan=z='min(1.0+on*0.0012,1.06)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1920x1080:fps=30,trim=duration=${logo_open},setpts=PTS-STARTPTS[v0];
        [1:v]scale=1920:1080,zoompan=z='max(1.10-on*0.00075,1.035)':x='iw/2-(iw/zoom/2)-45+on*0.65':y='ih/2-(ih/zoom/2)':d=1:s=1920x1080:fps=30,trim=duration=${dashboard_shot},setpts=PTS-STARTPTS[v1];
        [2:v]scale=1920:1080,zoompan=z='min(1.035+on*0.00065,1.09)':x='iw/2-(iw/zoom/2)+55-on*0.7':y='ih/2-(ih/zoom/2)':d=1:s=1920x1080:fps=30,trim=duration=${accounts_shot},setpts=PTS-STARTPTS[v2];
        [3:v]scale=1920:1080,zoompan=z='max(1.10-on*0.0008,1.035)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)+35-on*0.4':d=1:s=1920x1080:fps=30,trim=duration=${control_shot},setpts=PTS-STARTPTS[v3];
        [4:v]scale=1920:1080,zoompan=z='min(1.0+on*0.001,1.055)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1920x1080:fps=30,trim=duration=${logo_close},setpts=PTS-STARTPTS[v4];
        [v0][v1]xfade=transition=circleopen:duration=${transition}:offset=${offset_1}[x1];
        [x1][v2]xfade=transition=slideleft:duration=${transition}:offset=${offset_2}[x2];
        [x2][v3]xfade=transition=wipeup:duration=${transition}:offset=${offset_3}[x3];
        [x3][v4]xfade=transition=radial:duration=${transition}:offset=${offset_4},fade=t=out:st=${fade_out}:d=0.35[v];
        [5:a]aresample=48000,adelay=180:all=1,apad=pad_dur=0.57,afade=t=in:st=0:d=0.12,afade=t=out:st=${fade_out}:d=0.3[a]
      " \
      -map "[v]" -map "[a]" -t "$scene_duration" \
      -c:v libx264 -preset medium -crf 21 -pix_fmt yuv420p \
      -c:a aac -b:a 160k -ar 48000 -movflags +faststart "$segment_file"
  else
    ffmpeg -hide_banner -loglevel error -y \
      -loop 1 -framerate 30 -i "$slide_file" \
      -i "$audio_file" \
      -filter_complex "[0:v]scale=1920:1080,zoompan=z='min(zoom+0.00018,1.022)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1920x1080:fps=30,fade=t=in:st=0:d=0.3,fade=t=out:st=${fade_out}:d=0.35[v];[1:a]aresample=48000,adelay=180:all=1,apad=pad_dur=0.57,afade=t=in:st=0:d=0.12,afade=t=out:st=${fade_out}:d=0.3[a]" \
      -map "[v]" -map "[a]" -t "$scene_duration" \
      -c:v libx264 -preset medium -crf 21 -pix_fmt yuv420p \
      -c:a aac -b:a 160k -ar 48000 -movflags +faststart "$segment_file"
  fi
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
