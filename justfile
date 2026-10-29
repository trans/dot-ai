# List the recipes
default:
    @just --list

# Test dot-ai-mail (SH="zsh --emulate sh" just test, to try another shell)
test:
    sh tests/dot-ai-mail.sh

# Run the same tests against Arcana's carrier (ARCANA=/path/to/arcana, else the one on PATH)
test-arcana:
    CARRIER=arcana sh tests/dot-ai-mail.sh

# Check the plugin and marketplace manifests (needs Claude Code)
validate:
    claude plugin validate .

# Bring projects' .ai/ up to draft 0.3; prints what it would do unless given --apply (or --commit)
upgrade *args:
    python3 -I scripts/upgrade-to-0.3.py {{args}}
