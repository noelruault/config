
# [SETUP]

### If you want remove previous versions of hooks::
    rm .git/hooks/commit-msg .git/hooks/pre-commit
    rm .git/hooks/pre-commit-rubocop .git/hooks/pre-commit-prevent-master

### In order to link the hooks to the project and activate them on commit, you will need to make symlinks into .git folder as shown...
    ln -f $SCRIPTS_PATH/commit-msg .git/hooks/commit-msg
    ln -f $SCRIPTS_PATH/pre-commit .git/hooks/pre-commit
    ln -f $SCRIPTS_PATH/pre-commit-rubocop .git/hooks/pre-commit-rubocop
    ln -f $SCRIPTS_PATH/pre-commit-prevent-master .git/hooks/pre-commit-prevent-master

### And finally give permissions to the files, to allow them execute on commit::
    chmod u+x .git/hooks/commit-msg
    chmod u+x .git/hooks/pre-commit*


------------------------------


# [INFO]

## pre-commit:
- Hook that runs all files specified, containing hooks with useful checks.

## pre-commit-prevent-master
- Hook that prevents the user to push directly to master.

## pre-commit-rubocop
- Hook that uses rubocop gem to check if files changed in actual commit are good enough in order to commit them to the branch.

## commit-msg:
- Hook that check and alter commit message content based on given rules.

This uses concept of project tagging, if there environmental variable
PROJECT_TAGS defined or hard coded TAGS variable then it takes
it's value as possible tag words.

Example:
    PROJECT_TAGS=ISSUES, anotherissue

Commits themselves should use convention::

    'TAG-1234: Commit message'

To us branch as basis for commit message creation.
Then they should be in format::

    TAG-1234_some_optional_text



------------------------------

## Useful reference.
    https://coderwall.com/p/vt0lpg/pre-commit-hooks
