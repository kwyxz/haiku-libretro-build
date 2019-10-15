#!/bin/sh

HP_PATH="/boot/home/haikuports"

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

pull_json () {
  # pull JSON for latest commit
  curl -k -H "Content-type: application/json" -s "https://api.github.com/repos/libretro/$1/commits/refs/heads/master" -o "$2"
}

cd $HP_PATH
init_git "libretro-cores-update"

#while IFS= read -r COREFOLDER
#do

HP_CORE=$(echo "$1" | cut -d ':' -f 1)
HP_CORE_NAME=$(echo "$HP_CORE" | cut -d '/' -f 2)
HP_CORE_FOLDER=$(echo "$HP_PATH"/"$HP_CORE")
GH_CORE=$(echo "$1" | cut -d ':' -f 2)
GH_JSON="/tmp/_curl_git_$GH_CORE"

pull_json "$GH_CORE" "$GH_JSON"

GH_COMMIT=$(jq .sha "$GH_JSON" | tr -d \")
GH_DATE=$(jq .commit.author.date "$GH_JSON" | cut -d 'T' -f 1 | tr -d "-")
HP_RECIPE=$(ls -1 "$HP_CORE_FOLDER"/*.recipe)
HP_COMMIT=$(grep ^srcGitRev "$HP_CORE_FOLDER"/*.recipe | cut -d '=' -f 2 | tr -d \")
HP_VERSION=$(basename "$HP_RECIPE" | cut -d '-' -f 2 | sed -e 's/\.recipe//')
HP_CORE_DL=$(echo "$HP_CORE_FOLDER/download")
HP_CORE_ARCHIVE=$(echo "$HP_CORE_DL/$GH_CORE-$HP_VERSION-$GH_COMMIT.tar.gz")

if [ "$GH_COMMIT" == "$HP_COMMIT" ];
then
  echo "No need to update core $GH_CORE."
else
  echo "Updating core $GH_CORE... "
  mkdir -p "$HP_CORE_DL"
  wget "https://github.com/libretro/$GH_CORE/archive/$GH_COMMIT.tar.gz" -O "$HP_CORE_ARCHIVE"
  GH_SHA256SUM=$(sha256sum "$HP_CORE_ARCHIVE" | awk '{print $1}')
  sed -i -e s/^REVISION=\".\"/REVISION=\"1\"/ "$HP_RECIPE"
  sed -i -e s/^CHECKSUM_SHA256=\".*\"/CHECKSUM_SHA256=\"$GH_SHA256SUM\"/ "$HP_RECIPE"
  sed -i -e s/^srcGitRev=\".*\"/srcGitRev=\"$GH_COMMIT\"/ "$HP_RECIPE"
  git mv "$HP_RECIPE" "$HP_CORE_FOLDER"/"$HP_CORE_NAME"-"$HP_VERSION"_"$GH_DATE".recipe
fi

#done <<< $(grep -v ^# ./libretro_cores.list)
