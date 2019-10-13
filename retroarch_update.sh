#!/bin/sh

HP_PATH="/boot/home/haikuports"
RA_HP_PATH="$HP_PATH/games-emulation/retroarch"
RA_DL_PATH="$RA_HP_PATH/download"

die () {
  echo -e "\033[31mERROR:\e[0m $1"
  exit 1
}

init_git () {
  # remove pre-existing branch and create new one
  git checkout master
  git branch -D "$1"
  git checkout -b "$1"
}

close_git () {
  # commit changes and push
  git commit -a -m "$3: bump to version $2"
  git push --set-upstream origin "$1"
}

check_package_exists () {
  # make sure the package is built before pushing
  if [ -z "$1"]; then
    die "the $1 package has not been found"
  fi
}

TAG=$(curl -s https://api.github.com/repos/libretro/RetroArch/releases/latest | grep "tag_name" | cut -d ':' -f 2 | tr -d \" | tr -d \, | tr -d \v | tr -d ' ')
mkdir -p "$RA_DL_PATH"
cd "$RA_HP_PATH"

init_git "retroarch-dev-$TAG"

RA_ARCHIVE="$RA_DL_PATH/retroarch-$TAG.tar.gz"
wget "https://github.com/libretro/RetroArch/archive/v$TAG.tar.gz" -O "$RA_ARCHIVE"

SHA256SUM=$(sha256sum "$RA_ARCHIVE" | awk '{print $1}')
CURRENT=$(ls -1 "$RA_HP_PATH"/*.recipe)
# update the recipe
sed -i -e s/CHECKSUM_SHA256=\".*\"/CHECKSUM_SHA256=\"$SHA256SUM\"/ "$CURRENT"
sed -i -e s/REVISION=\".\"/REVISION=\"1\"/ "$CURRENT"

git mv "$CURRENT" "$RA_HP_PATH/retroarch-$TAG.recipe"

check_package_exists "$HP_PATH/packages/retroarch-1.7.9.2-1-x86_64.hpkg"

close_git "retroarch-dev-$TAG" "$TAG" "RetroArch"
