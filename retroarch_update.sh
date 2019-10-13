#!/bin/sh

HP_PATH="/boot/home/haikuports"
RA_HP_PATH="$HP_PATH/games-emulation/retroarch"
RA_DL_PATH="$RA_HP_PATH/download"
RA_VERSION=$(curl -s https://api.github.com/repos/libretro/RetroArch/releases/latest | grep "tag_name" | cut -d ':' -f 2 | tr -d \" | tr -d \, | tr -d \v | tr -d ' ')
RA_ARCHIVE="$RA_DL_PATH/retroarch-$RA_VERSION.tar.gz"

# functions
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

build_package () {
  HP=$(command -v haikuporter)
  $HP -S -j8 --get-dependencies --no-source-packages $1
}

check_package_exists () {
  # make sure the package is built before pushing
  if [ -z "$1" ]; then
    die "the $1 package has not been found"
  fi
}

# create download folder
mkdir -p "$RA_DL_PATH"
cd "$RA_HP_PATH"

init_git "retroarch-dev-$RA_VERSION"

wget "https://github.com/libretro/RetroArch/archive/v$RA_VERSION.tar.gz" -O "$RA_ARCHIVE"

SHA256SUM=$(sha256sum "$RA_ARCHIVE" | awk '{print $1}')
CURRENT=$(ls -1 "$RA_HP_PATH"/*.recipe)
# update the recipe
sed -i -e s/CHECKSUM_SHA256=\".*\"/CHECKSUM_SHA256=\"$SHA256SUM\"/ "$CURRENT"
sed -i -e s/REVISION=\".\"/REVISION=\"1\"/ "$CURRENT"

git mv "$CURRENT" "$RA_HP_PATH/retroarch-$RA_VERSION.recipe"

build_package "retroarch"
check_package_exists "$HP_PATH/packages/retroarch-$RA_VERSION-1-x86_64.hpkg"

close_git "retroarch-dev-$RA_VERSION" "$RA_VERSION" "RetroArch"
