# Where Claude Code and Codex look for skills (CLAUDE_CONFIG_DIR and CODEX_HOME move them)
claude_skills := env("CLAUDE_CONFIG_DIR", home_directory() / ".claude") / "skills"
codex_skills := env("CODEX_HOME", home_directory() / ".codex") / "skills"

# List the recipes
default:
    @just --list

# Install the dot-ai skill for Claude Code and Codex: copies of skill/, replacing what's there
install: (install-to claude_skills) (install-to codex_skills)

# Show how the installed copies differ from skill/ (check before installing over edits)
diff: (diff-from claude_skills) (diff-from codex_skills)

# Copy skill/ to DIR/dot-ai, unless the tool DIR belongs to isn't installed
[private]
install-to dir:
    @if [ -d "{{parent_directory(dir)}}" ]; then \
        mkdir -p "{{dir}}/dot-ai" && rsync -a --delete skill/ "{{dir}}/dot-ai/" && echo "Installed {{dir}}/dot-ai"; \
    else echo "Skipped {{dir}}: {{parent_directory(dir)}} doesn't exist"; fi

[private]
diff-from dir:
    @diff -ru "{{dir}}/dot-ai" skill && echo "{{dir}}/dot-ai matches skill/" || true
