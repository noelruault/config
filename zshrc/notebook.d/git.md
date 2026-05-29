
  (1) git fetch origin
  (1) git reset origin
  (2) git fetch origin
  (2) git reset --hard origin
  (?) git reset --hard HEAD
  # Remove all untracked files Git
  git clean -df
  #	-d  :remove whole directories
  # 	-f  :force
  [[Source: https://stackoverflow.com/a/102309/4349318]]

  Remove branches?
  * Deleting local branches
    git branch -d <branch_name>
  * Deleting remote branches
    git push origin :<branch_name>
    git push origin --delete <branch_name>

  [[Source: https://www.educative.io/edpresso/how-to-delete-remote-branches-in-git]]

  Remove existing  files from the repository:
  find . -name .DS_Store -print0 | xargs -0 git rm -f --ignore-unmatch


  Squash all commits into one:
    git checkout yourBranch
    git reset 
    git add -A
    git commit -m one commit on yourBranch

  
