#!/usr/bin/env sh
# Installs the codegraph skill for your user account so /codegraph works in every project.
#   ./install.sh            -> ~/.claude/skills/codegraph   (Claude Code; VS Code Copilot also reads this)
#   ./install.sh --copilot  -> also ~/.copilot/skills/codegraph
set -e
src="$(cd "$(dirname "$0")" && pwd)/.claude/skills/codegraph"
targets="$HOME/.claude/skills/codegraph"
[ "$1" = "--copilot" ] && targets="$targets $HOME/.copilot/skills/codegraph"
for dst in $targets; do
  mkdir -p "$dst/scripts"
  cp "$src/SKILL.md" "$dst/"
  cp "$src/scripts/"* "$dst/scripts/"
  echo "installed -> $dst"
done
command -v node >/dev/null 2>&1 || echo "warning: Node.js (16+) is required to run the skill: https://nodejs.org"
