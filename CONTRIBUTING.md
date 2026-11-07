# Working on this mod together

Each version goes on its own branch, named for the person who made it and the
day: `<first name>_MMDDYY`. Casey's work on November 7, 2026 is `Casey_110726`;
Lucas's work that day would be `Lucas_110726`.

## Before you change anything

```
powershell -File tools/New-DayBranch.ps1
```

This switches you to today's branch, named from your git name (`git config
user.name`). If the branch does not exist yet it is made from the commit you
are on, so first check out the newest branch you want to build on. Your
uncommitted changes come along to a new branch. Add `-Push` to put a new branch
on GitHub straight away; `-Name Lucas` sets the name if git has another one.

It also turns on a check that runs before every `git push`: a branch named
`<name>_MMDDYY` can only be pushed by that person, so nobody's version ends up
under someone else's name. Other branches (`main`, `dev`) are not checked.

## Then

Commit on your branch and push it (`git push -u origin <your branch>`).
`main` and `dev` change only when Casey decides, and new releases (what the
"Warhammer NVDA Update" shortcut installs) are published by Casey.

`CLAUDE.md` has the project's rules and current state; Claude Code sessions
follow it, including this branch naming.
