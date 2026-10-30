#!/bin/bash
# Checks that stranded, stranded-pi, stranded-web and this site are all
# pushed, released, built and deployed, and offers to fix what isn't:
#
#   stranded            commits not pushed, or not in a release
#   stranded-pi         commits not pushed, or no image of the latest release
#                       of stranded built since setup.sh or image/ changed
#   stranded-web        commits not pushed, or dist not a build of its code
#   stranded.bert.org   not the latest image, or the live site isn't what a
#                       build would be now (eg. an older stranded-web)
#
# The other repositories are expected next to this one. Each fix depends on
# the ones before it, so they're offered in that order. Without a terminal
# (or with -n) it only reports, with the commands to run. Exits 1 if anything
# needs doing.
set -euo pipefail

SITE=$(cd "$(dirname "$0")" && pwd)
CODE=$(dirname "$SITE")
STRANDED=$CODE/stranded
PI=$CODE/stranded-pi
WEB=$CODE/stranded-web
LIVE=https://stranded.bert.org

interactive=
[ -t 0 ] && interactive=1
[ "${1:-}" = -n ] && interactive=

issues=0

say() { echo; echo "== $*"; }
note() { echo "  $*"; }

# problem <description> <fix, as shown> <command...>: reports it, and asks to
# run the command
problem() {
    local what=$1 fix=$2
    shift 2
    issues=$((issues + 1))
    echo "  ! $what"
    if [ -z "$interactive" ]; then
        echo "    to fix: $fix"
        return 1
    fi
    local answer
    read -r -p "    $fix? [y/N] " answer
    case "$answer" in
        y | Y | yes)
            if "$@"; then
                issues=$((issues - 1))
                return 0
            fi
            echo "    That failed" >&2
            exit 1
            ;;
    esac
    return 1
}

mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }

# Uncommitted changes aren't in any push, release or build, so only a warning
check_clean() {   # check_clean <repo> [paths...]
    local repo=$1
    shift
    if [ -n "$(git -C "$repo" status --porcelain -- "$@")" ]; then
        note "warning: uncommitted changes in $(basename "$repo")${1:+ (in $*)}"
    fi
}

# Returns 1 if the branch is still behind or ahead of its upstream
check_pushed() {   # check_pushed <repo>
    local repo=$1 name ahead behind
    name=$(basename "$repo")
    ahead=$(git -C "$repo" rev-list --count '@{u}..HEAD')
    behind=$(git -C "$repo" rev-list --count 'HEAD..@{u}')
    if [ "$behind" -gt 0 ]; then
        note "warning: $name is $behind commit(s) behind $(git -C "$repo" rev-parse --abbrev-ref '@{u}'): pull first"
        return 1
    fi
    if [ "$ahead" -gt 0 ]; then
        problem "$name has $ahead commit(s) that aren't pushed" "git push in $name" git -C "$repo" push || return 1
    fi
}

release_stranded() { (cd "$STRANDED" && scripts/release); }
BUILD_IMAGE="Build it with stranded-pi's image/build-site.sh (needs Docker, and takes a while)"
build_image() { SITE_DIR=$SITE "$PI/image/build-site.sh"; }
build_web() { (cd "$WEB" && npm run build); }
install_site() { (cd "$SITE" && npm install); }
deploy_site() { "$SITE/deploy.sh"; }

# Copies the image stranded-pi built last, as image/build-site.sh does
copy_image() {
    mkdir -p "$SITE/public/images" &&
    cp "$PI/image/out/$image" "$PI/image/out/$image.sha256" "$SITE/public/images/" &&
    cp "$PI/image/out/repo.json" "$SITE/public/repo.json"
}

echo "Fetching"
for repo in "$STRANDED" "$PI" "$WEB" "$SITE"; do
    git -C "$repo" fetch --quiet --tags
done

say "stranded"
check_clean "$STRANDED"
stranded_pushed=1
check_pushed "$STRANDED" || stranded_pushed=
release=$(git -C "$STRANDED" tag -l 'v*' --sort=-v:refname | head -1)
unreleased=$(git -C "$STRANDED" rev-list --count "$release..HEAD")
note "latest release $release"
if [ "$unreleased" -gt 0 ]; then
    if [ -n "$stranded_pushed" ]; then
        problem "$unreleased commit(s) since $release" "Release them with stranded's scripts/release" release_stranded &&
            release=$(git -C "$STRANDED" tag -l 'v*' --sort=-v:refname | head -1)
    else
        issues=$((issues + 1))
        echo "  ! $unreleased commit(s) since $release"
        echo "    to fix: push, then release them with stranded's scripts/release"
    fi
fi

say "stranded-pi"
check_clean "$PI" setup.sh image
check_pushed "$PI" || true
# The image is named after the version of stranded in it, and repo.json
# lists the last one built
image=
if [ -f "$PI/image/out/repo.json" ]; then
    image=$(sed -n 's|.*"url": "[^"]*/\(stranded-[^"/]*\.img\.xz\)".*|\1|p' "$PI/image/out/repo.json")
fi
image_version=$(echo "$image" | sed -n 's/^stranded-\(.*\)-raspios-.*/\1/p')
changed=$(git -C "$PI" log -1 --format=%ct -- setup.sh image)
if [ -z "$image" ]; then
    problem "no image built" "$BUILD_IMAGE" build_image || true
elif [ "v$image_version" != "$release" ]; then
    problem "the last image built, $image, has stranded $image_version, not $release" "$BUILD_IMAGE" build_image || true
elif [ "$(mtime "$PI/image/out/repo.json")" -lt "$changed" ]; then
    problem "$image was built before setup.sh or image/ last changed ($(git -C "$PI" log -1 --format='%h %s' -- setup.sh image))" "$BUILD_IMAGE" build_image || true
else
    note "image $image"
fi
# A build may have just changed it
[ -f "$PI/image/out/repo.json" ] &&
    image=$(sed -n 's|.*"url": "[^"]*/\(stranded-[^"/]*\.img\.xz\)".*|\1|p' "$PI/image/out/repo.json")

say "stranded-web"
check_clean "$WEB" src
check_pushed "$WEB" || true
# A build of the library alone takes a second, and is the only sure way to
# tell whether dist has the code as it is now
web_build=$(mktemp -d)
trap 'rm -rf "$web_build"' EXIT
if [ ! -f "$WEB/dist/stranded.js" ]; then
    problem "stranded-web isn't built" "npm run build in stranded-web" build_web || true
elif ! (cd "$WEB" && node_modules/.bin/vite build --outDir "$web_build" --logLevel error </dev/null) ||
     ! cmp -s "$web_build/stranded.js" "$WEB/dist/stranded.js"; then
    problem "dist isn't a build of stranded-web as it is now" "npm run build in stranded-web" build_web || true
else
    note "dist is up to date"
fi

say "stranded.bert.org"
check_clean "$SITE"
check_pushed "$SITE" || true
if [ "$(readlink "$SITE/node_modules/stranded-web" 2>/dev/null)" != ../../stranded-web ]; then
    problem "node_modules/stranded-web isn't linked to ../stranded-web" "npm install" install_site || true
fi
if [ -n "$image" ] && ! cmp -s "$PI/image/out/repo.json" "$SITE/public/repo.json"; then
    problem "public/ doesn't have stranded-pi's latest image, $image" "Copy it in from stranded-pi's image/out" copy_image || true
fi
# Vite names the JavaScript and CSS after their contents, so index.html
# changes with them, eg. for a newer stranded-web
echo "  building, to compare with $LIVE"
if ! (cd "$SITE" && npm run build </dev/null >/dev/null 2>&1); then
    issues=$((issues + 1))
    echo "  ! the site doesn't build: run npm run build to see why"
elif ! curl -fsS "$LIVE/" | cmp -s - "$SITE/dist/index.html" ||
     ! curl -fsS "$LIVE/repo.json" | cmp -s - "$SITE/public/repo.json"; then
    problem "$LIVE isn't the same as a build now" "Deploy with ./deploy.sh" deploy_site || true
elif ! curl -fsSI -o /dev/null "$(sed -n 's|.*"url": "\(https://stranded.bert.org/images/[^"]*\)".*|\1|p' "$SITE/public/repo.json")"; then
    problem "the image repo.json lists isn't on $LIVE" "Deploy with ./deploy.sh" deploy_site || true
else
    note "$LIVE is up to date"
fi

echo
if [ "$issues" -gt 0 ]; then
    echo "$issues thing(s) to do"
    exit 1
fi
echo "Everything is pushed, released, built and deployed"
