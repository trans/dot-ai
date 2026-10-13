# Claude Code's skills directory (CLAUDE_CONFIG_DIR moves it)
skills := env("CLAUDE_CONFIG_DIR", home_directory() / ".claude") / "skills"

# List the recipes
default:
    @just --list

# Install the dot-ai skill for Claude Code: a copy of skill/, replacing what's there
install:
    mkdir -p "{{skills}}/dot-ai"
    rsync -a --delete skill/ "{{skills}}/dot-ai/"
    @echo "Installed {{skills}}/dot-ai"

# Show how the installed skill differs from skill/ (check before installing over edits)
diff:
    @diff -ru "{{skills}}/dot-ai" skill && echo "The installed skill matches skill/" || true
