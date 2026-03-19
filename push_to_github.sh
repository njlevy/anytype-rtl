#!/bin/bash
# Push anytype-rtl to GitHub as a public repo
set -e

cd "$(dirname "$0")"

if command -v gh &> /dev/null; then
    echo "Creating public repo and pushing..."
    gh repo create anytype-rtl --public --source=. --push
    echo ""
    echo "Done! Repo is live at: https://github.com/$(gh api user -q .login)/anytype-rtl"
else
    echo "gh CLI not found. Install it with: brew install gh"
    echo ""
    echo "Or push manually:"
    echo "  cd $(pwd)"
    echo "  git remote add origin https://github.com/YOUR_USERNAME/anytype-rtl.git"
    echo "  git push -u origin main"
fi
