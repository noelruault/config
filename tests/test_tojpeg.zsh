#!/usr/bin/env zsh
source "${0:A:h}/lib.zsh"
t_sandbox

if ! command -v sips >/dev/null 2>&1; then
    t "sips present"; t_skip "not macOS"; t_done
fi

bin=$REPO/bin/to-jpeg
cd "$T_DIR"
sips -s format png /System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns --out "a b.png" >/dev/null 2>&1
print junk > bad.png

t "converts beside the original, spaces ok"
out=$("$bin" "a b.png"); assert_eq "$?" 0; assert_eq "$out" "a b.jpg"
assert_eq "$(sips -g format "a b.jpg" | awk '/format/{print $2}')" jpeg

t "never overwrites"
assert_eq "$("$bin" "a b.png")" "a b-1.jpg"

t "-z bounds the long edge"
"$bin" -z 64 "a b.png" >/dev/null
assert_eq "$(sips -g pixelWidth "a b-2.jpg" | awk '/pixelWidth/{print $2}')" 64

t "bad, missing and jpeg inputs: others still convert, exit 1"
err=$("$bin" bad.png missing.heic "a b.jpg" "a b.png" 2>&1 >/dev/null); assert_eq "$?" 1
assert_contains "$err" "fail bad.png"; assert_contains "$err" "skip missing.heic"; assert_contains "$err" "skip a b.jpg: already JPEG"
assert_file_exists "a b-3.jpg"; [[ ! -e bad.jpg ]] && _t_pass || _t_fail "bad.jpg left behind"

t "usage errors exit 2"
"$bin" 2>/dev/null; assert_eq "$?" 2
"$bin" -z x "a b.png" 2>/dev/null; assert_eq "$?" 2

t_done
