#!/bin/bash

current_version=$(nvim --headless --noplugin -u ./docgen/minimal_init.vim -c 'luafile ./scripts/get_version.lua' -c 'qa' 2>&1 | tr -d \")

# get current commit hash for tag
commit=$(git rev-parse HEAD)

push_tag() {

curl -s -X POST https://api.github.com/repos/nvim-neorg/neorg/git/refs \
-H "Authorization: token $GITHUB_TOKEN" \
-d @- << EOF
{
  "ref": "refs/tags/$current_version",
  "sha": "$commit"
}
EOF
echo "Generated new tag: $current_version"

if [ $(git tag -l "latest") ]; then

curl -s -X PATCH https://api.github.com/repos/nvim-neorg/neorg/git/refs \
-H "Authorization: token $GITHUB_TOKEN" \
-d @- << EOF
{
  "ref": "refs/tags/latest",
  "sha": "$commit"
}
EOF
echo "Changed tag 'latest', based of $current_version"

else
curl -s -X POST https://api.github.com/repos/nvim-neorg/neorg/git/refs \
-H "Authorization: token $GITHUB_TOKEN" \
-d @- << EOF
{
  "ref": "refs/tags/latest",
  "sha": "$commit"
}
EOF
echo "Generated new tag: 'latest', based of $current_version"

fi
}

echo "Current neorg version: $current_version"
echo "Last commit: $commit"


if [ $(git tag -l "$current_version") ]; then
    echo "No new Neorg version (current: $current_version)"
    exit 0
else

    push_tag
fi
