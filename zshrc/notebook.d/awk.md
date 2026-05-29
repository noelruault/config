
gsub -> http://www.endmemo.com/r/gsub.php
e.g:
    $ go test ./... | awk '{ gsub("PASS", "\033[0;32m&\033[0m"); print }'

to replace specific file content
    awk '{sub(/PRIVATE_KEY_PLACEHOLDER/,<PRIVATE_KEY_HERE>)}1' metadata.json > dist/metadata.json
  
