---
description: write git commit message
---

Automatically stage the modified files (git add .).  write a git commit message for the changes made to the modified files.

**Critical Rules**
- Do not run the git commit command, generate the message only. The user will copy/paste this message and run the command.
- **File References**: When referencing files in the commit message, NEVER use directory paths or file extensions (e.g. use `git-commit workflow` instead of `.agents/workflows/git-commit.md`). The chat UI will aggressively text-replace anything resembling a file path into an uncopyable link.
- **NO LINKS**: NEVER generate markdown links (`[file](...)`), absolute paths, or `cci:` links in the commit message output.
- Print the entire commit message inside a single markdown code block (viz. ` ```text `) to prevent the chat UI from auto-linking paths.
