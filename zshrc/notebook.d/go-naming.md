
  - Name everything for what it provides, not what it contains.
  - Short variable names work well when the distance between their declaration and last use is short.
  - Long variable names need to justify themselves; the longer they are the more value they need to provide.
    Lengthy bureaucratic names carry a low amount of signal compared to their weight on the page.
  - Don't include the name of your type in the name of your variable.
  - Constants should describe the value they hold, not how that value is used.
  - Prefer single letter variables for loops and branches, single words for parameters and return values, multiple words for functions and package level declaration.
  - Prefer single words for methods, interfaces, and packages.
  - Remember that the name of a package is part of the name the caller uses to to refer to it, so make use of that.
  - Don't mix and match long and short formal parameters in the same declaration.

  [Reference]: https://dave.cheney.net/practical-go/presentations/qcon-china.html#_identifiers
  
