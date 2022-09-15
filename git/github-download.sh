#!/bin/bash

brew list gh &> /dev/null || brew install gh
gh auth status &> /dev/null || gh auth login

read -p "Enter username or organization: " TARGET

GITHUB_GOPATH=$(go env GOPATH)/src/github.com
if ! [ -d $GITHUB_GOPATH ]; then
    mkdir -p $GITHUB_GOPATH
fi

cd $GITHUB_GOPATH
gh repo list $TARGET --limit 50 | while read -r repo _; do
  gh repo clone "$repo" "$repo" -- -q 2>/dev/null || (
    cd "$repo"
    # Handle case where local checkout is on a non-main/master branch
    # - ignore checkout errors because some repos may have zero commits, so no main or master
    git checkout -q main 2>/dev/null || true
    git checkout -q master 2>/dev/null || true
    git pull -q
  )
done
