
  > means truncate and write
  >> means append
  ( appending to or writing to /dev/null has the same net effect )

  2>&1 redirects standard error STDERR (2) to standard output STDOUT (1),
  which then discards it as well since standard output has already been redirected.

  [[Source: https://stackoverflow.com/a/10508862/4349318]]
  
