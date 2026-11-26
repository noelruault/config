#!/usr/bin/env zsh
source "${0:A:h}/lib.zsh"
t_sandbox

path=(/opt/homebrew/bin /usr/local/bin $path)
if ! command -v cwebp >/dev/null 2>&1 || ! command -v sips >/dev/null 2>&1; then
    t "cwebp + sips present"; t_skip "macOS + brew install webp"; t_done
fi

bin=$REPO/bin/to-webp
cd "$T_DIR"
icns=/System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns
sips -s format png $icns --out "a b.png" >/dev/null 2>&1
sips -s format heic $icns --out photo.heic >/dev/null 2>&1
print junk > bad.png

t "converts beside the original, spaces ok"
out=$("$bin" "a b.png"); assert_eq "$?" 0; assert_eq "$out" "a b.webp"
assert_eq "$(sips -g format "a b.webp" | awk '/format/{print $2}')" webp

t "formats cwebp cannot read go through sips"
assert_eq "$("$bin" photo.heic)" "photo.webp"
assert_eq "$(sips -g format photo.webp | awk '/format/{print $2}')" webp

t "never overwrites"
assert_eq "$("$bin" "a b.png")" "a b-1.webp"

t "-q changes the output"
"$bin" -q 5 "a b.png" >/dev/null
(( $(stat -f %z "a b-2.webp") < $(stat -f %z "a b.webp") )) && _t_pass || _t_fail "-q 5 not smaller than -q 85"

t "bad, missing and webp inputs: others still convert, exit 1"
err=$("$bin" bad.png missing.heic "a b.webp" "a b.png" 2>&1 >/dev/null); assert_eq "$?" 1
assert_contains "$err" "fail bad.png"; assert_contains "$err" "skip missing.heic"; assert_contains "$err" "skip a b.webp: already WebP"
assert_file_exists "a b-3.webp"; [[ ! -e bad.webp ]] && _t_pass || _t_fail "bad.webp left behind"

t "usage errors exit 2"
"$bin" 2>/dev/null; assert_eq "$?" 2
"$bin" -q 101 "a b.png" 2>/dev/null; assert_eq "$?" 2

t_done
