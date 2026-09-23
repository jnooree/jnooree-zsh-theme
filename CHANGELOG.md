# Changelog

Notable changes to this theme. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Releases are
rolling and named by date.

## 2026-09-23

### Changed

- Git information now comes from one `git status --porcelain=v2` call
  instead of `vcs_info` and its patched backends; two git processes per prompt.
- Requires git 2.36 or later.
- All theme functions and globals renamed under the `_jnr_` prefix.

### Added

- Entry counts after every status marker: `+2!1=1?3`.
- Red `=` marker for unmerged (conflicted) entries.
- `DISABLE_GIT_PROMPT` to turn the git segment off per shell or per directory.
- `GIT_PROMPT_TIMEOUT` (default 1 s); expired git commands are killed and the
  segment shows `!timeout!`.

### Removed

- `functions/` directory. Drop `-f functions` from the `zmodule` line.

## 2026-09-22

### Added

- Tag name instead of a hash when HEAD is detached at a tag.
- Terminal title is skipped on `dumb` and `linux` terminals.

### Fixed

- Trailing NUL in the repository path when the prompt ran inside `.git`.
- False unstaged marker inside a separate git directory.
- `stashcnt` leaking into the global scope.
- Prompt git commands no longer take optional locks (`GIT_OPTIONAL_LOCKS=0`).
- Control characters in the command are shown escaped in the terminal title.
