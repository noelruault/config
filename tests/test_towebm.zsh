#!/usr/bin/env zsh
source "${0:A:h}/lib.zsh"
t_sandbox

path=(/opt/homebrew/bin /usr/local/bin $path)
if ! command -v ffmpeg >/dev/null 2>&1; then
    t "ffmpeg present"; t_skip "brew install ffmpeg"; t_done
fi

bin=$REPO/bin/to-webm
cd "$T_DIR"
ffmpeg -nostdin -loglevel error -f lavfi -i testsrc=size=64x48:rate=10:duration=1 \
    -f lavfi -i sine=duration=1 -c:v mpeg4 -c:a aac -shortest "a b.mov"
ffmpeg -nostdin -loglevel error -f lavfi -i testsrc=size=64x48:rate=10:duration=1 -c:v mpeg4 silent.mov
print junk > bad.mov

t "converts beside the original to VP9 + Opus, spaces ok"
out=$("$bin" "a b.mov"); assert_eq "$?" 0; assert_eq "$out" "a b.webm"
assert_eq "$(ffprobe -v error -show_entries stream=codec_name -of csv=p=0 "a b.webm" | tr '\n' ' ')" "vp9 opus "

t "video without audio still converts"
assert_eq "$("$bin" silent.mov)" "silent.webm"

t "never overwrites"
assert_eq "$("$bin" "a b.mov")" "a b-1.webm"

t "bad, missing and webm inputs: others still convert, exit 1"
err=$("$bin" bad.mov missing.mp4 "a b.webm" "a b.mov" 2>&1 >/dev/null); assert_eq "$?" 1
assert_contains "$err" "fail bad.mov"; assert_contains "$err" "skip missing.mp4"; assert_contains "$err" "skip a b.webm: already WebM"
assert_file_exists "a b-2.webm"; [[ ! -e bad.webm ]] && _t_pass || _t_fail "bad.webm left behind"

t "usage errors exit 2"
"$bin" 2>/dev/null; assert_eq "$?" 2
"$bin" -x "a b.mov" 2>/dev/null; assert_eq "$?" 2

t_done
