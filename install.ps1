# Installs the codegraph skill for your user account so /codegraph works in every project.
#   .\install.ps1            -> ~/.claude/skills/codegraph   (Claude Code; VS Code Copilot also reads this)
#   .\install.ps1 -Copilot   -> also ~/.copilot/skills/codegraph
param([switch]$Copilot)
$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot '.claude\skills\codegraph'
$targets = @(Join-Path $HOME '.claude\skills\codegraph')
if ($Copilot) { $targets += Join-Path $HOME '.copilot\skills\codegraph' }
foreach ($dst in $targets) {
  New-Item -ItemType Directory -Force (Join-Path $dst 'scripts') | Out-Null
  Copy-Item (Join-Path $src 'SKILL.md') $dst -Force
  Copy-Item (Join-Path $src 'scripts\*') (Join-Path $dst 'scripts') -Force
  Write-Host "installed -> $dst"
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Write-Warning 'Node.js (16+) is required to run the skill: https://nodejs.org' }
