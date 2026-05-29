Next is shown the shorter output of a zprof run, detailing what is consuming more time on loading:

  If zshrc is taking too long to initialise you may want to speed up loading times, try out the following opts:
  - '/usr/bin/time zsh -i -c exit' to trace initialisation times or even 'for i in $(seq 1 10); do /usr/bin/time $SHELL -i -c exit; done'
  - Have a look here if you want to debug these times: https://blog.jonlu.ca/posts/speeding-up-zsh
  - 'sudo rm /private/var/log/asl/*.asl' to clean dangling files that could be causing slow loading times # Why?: https://osxdaily.com/2010/05/06/speed-up-a-slow-terminal-by-clearing-log-files/
  - 'mv ~/.zsh_history ~/.zsh_history.$(date '+%Y%m%d').backup' to backup history which can be causing lags
  - You COULD create a dump for the compinit file, that will cause compinit to not reload everytime: 'compinit -d dumpfile'
  
