# Where Claude Code and Codex look for skills (CLAUDE_CONFIG_DIR and CODEX_HOME move them)
claude_skills := env("CLAUDE_CONFIG_DIR", home_directory() / ".claude") / "skills"
codex_skills := env("CODEX_HOME", home_directory() / ".codex") / "skills"
# Where dot-ai-mail goes, so hooks and people can run it by name
bin := home_directory() / ".local" / "bin"

# List the recipes
default:
    @just --list

# Install the dot-ai skill for Claude Code and Codex (copies of skill/, replacing what's there), and dot-ai-mail in ~/.local/bin
install: (install-to claude_skills) (install-to codex_skills)
    @mkdir -p "{{bin}}" && cp skill/scripts/dot-ai-mail "{{bin}}/dot-ai-mail" && chmod 755 "{{bin}}/dot-ai-mail" && echo "Installed {{bin}}/dot-ai-mail"

# Show how the installed copies differ from skill/ (check before installing over edits)
diff: (diff-from claude_skills) (diff-from codex_skills)
    @cmp -s skill/scripts/dot-ai-mail "{{bin}}/dot-ai-mail" && echo "{{bin}}/dot-ai-mail matches" || echo "{{bin}}/dot-ai-mail differs or is missing"

# Test dot-ai-mail (SH="zsh --emulate sh" just test, to try another shell)
test:
    sh tests/dot-ai-mail.sh

# Bring projects' .ai/ up to draft 0.3; prints what it would do unless given --apply (or --commit)
upgrade *args:
    python3 -I scripts/upgrade-to-0.3.py {{args}}

# Copy skill/ to DIR/dot-ai, unless the tool DIR belongs to isn't installed
[private]
install-to dir:
    @if [ -d "{{parent_directory(dir)}}" ]; then \
        mkdir -p "{{dir}}/dot-ai" && rsync -a --delete skill/ "{{dir}}/dot-ai/" && echo "Installed {{dir}}/dot-ai"; \
    else echo "Skipped {{dir}}: {{parent_directory(dir)}} doesn't exist"; fi

[private]
diff-from dir:
    @diff -ru "{{dir}}/dot-ai" skill && echo "{{dir}}/dot-ai matches skill/" || true
