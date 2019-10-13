#!/bin/sh

init_git () {
  git checkout master
  git branch -D "$1"
  git checkout -b "$1"
}

close_git () {
  git commit -a -m "$3: bump to version $2"
  git push --set-upstream origin "$1"
}

RA_HP_PATH="/boot/home/haikuports/games-emulation/retroarch"
TAG=$(curl -s https://api.github.com/repos/libretro/RetroArch/releases/latest | grep "tag_name" | cut -d ':' -f 2 | tr -d \" | tr -d \, | tr -d \v | tr -d ' ')
mkdir -p "$RA_HP_PATH"/download
RA_ARCHIVE="$RA_HP_PATH/download/retroarch-$TAG.tar.gz"
cd "$RA_HP_PATH"

init_git "retroarch-dev-$TAG"

wget "https://github.com/libretro/RetroArch/archive/v$TAG.tar.gz" -O "$RA_ARCHIVE"

SHA256SUM=$(sha256sum "$RA_ARCHIVE" | awk '{print $1}')
CURRENT=$(ls -1 "$RA_HP_PATH"/*.recipe)

sed -i -e s/CHECKSUM_SHA256=\".*\"/CHECKSUM_SHA256=\"$SHA256SUM\"/ "$CURRENT"
sed -i -e s/REVISION=\".\"/REVISION=\"1\"/ "$CURRENT"
git mv "$CURRENT" /boot/home/haikuports/games-emulation/retroarch/retroarch-$TAG.recipe

close_git "retroarch-dev-$TAG" "$TAG" "RetroArch"
