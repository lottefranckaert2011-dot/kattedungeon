#!/bin/bash
# Records the two CrazyGames preview videos (no audio, 15-20 s) with Godot's Movie Maker.
# Usage: GODOT=/path/to/godot4.3 tools/make_videos.sh
# Needs: ffmpeg, and xvfb-run on a machine without a screen.
# Output: store/video_landscape_1920x1080.mp4 and store/video_portrait_1080x1620.mp4
# Each video opens with ~1 s of the matching cover (run tools/make_covers.py first).
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
TMP=$(mktemp -d)
run_godot() {
	if [ -z "$DISPLAY" ] && command -v xvfb-run >/dev/null; then
		xvfb-run -a -s "-screen 0 1920x1700x24" "$GODOT" "$@"
	else
		"$GODOT" "$@"
	fi
}
"$GODOT" --headless --import >/dev/null 2>&1 || true

record() {  # $1 = landscape|portrait, $2 = cover, $3 = output, $4 = video size, $5 = window
	# The game frames are blown up 4x with sharp pixels, then scaled to the video size.
	mkdir -p "$TMP/$1"
	run_godot --path . --resolution "$5" --fixed-fps 30 --write-movie "$TMP/$1/f.png" res://tests/trailer_runner.tscn -- "$1" >/dev/null 2>&1 || true
	ffmpeg -y -loglevel error \
		-loop 1 -framerate 30 -t 1.2 -i "$2" \
		-framerate 30 -i "$TMP/$1/f%08d.png" \
		-filter_complex "[0:v]scale=$4,setsar=1,format=yuv420p[c];[1:v]scale=iw*4:ih*4:flags=neighbor,scale=$4:flags=area,setsar=1,format=yuv420p[g];[c][g]concat=n=2:v=1:a=0[v]" \
		-map "[v]" -an -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -movflags +faststart "$3"
	echo "made $3"
}

record landscape store/cover_landscape_1920x1080.png store/video_landscape_1920x1080.mp4 1920:1080 1920x1080
# The portrait cover is 800x1200 (2:3); it is scaled up to the 1080x1620 video size.
record portrait store/cover_portrait_800x1200.png store/video_portrait_1080x1620.mp4 1080:1620 1080x1620
rm -rf "$TMP"
