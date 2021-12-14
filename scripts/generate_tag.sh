#!/bin/bash

current_version=$(nvim --headless --noplugin -u ./docgen/minimal_init.vim -c 'luafile ./scripts/get_version.lua' -c 'qa' 2>&1 | tr -d \")

last_tag=$(git describe --tags `git rev-list --tags --max-count=1` 2>/dev/null)

push_tag() {
    # get current commit hash for tag
    commit=$(git rev-parse HEAD)

curl -s -X POST https://api.github.com/repos/nvim-neorg/neorg/git/refs \
-H "Authorization: token $GITHUB_TOKEN" \
-d @- << EOF
{
  "ref": "refs/tags/$current_version",
  "sha": "$commit"
}
EOF
}

if [ -z "$last_tag" ]; then
    # git tag -a $current_version -m "Neorg version: $current_version"
    push_tag
    echo "Generated new tag: $current_version"
    exit 0
fi

if [[ "$current_version" == "$last_tag" ]]; then
    echo "No new Neorg version (current: $current_version)"
    exit 0
else
    push_tag
    echo "Generated new tag: $current_version"
fi

