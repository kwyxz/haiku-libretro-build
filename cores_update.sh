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

#while IFS= read -r COREFOLDER
#do

HP_CORE="$HP_PATH"/"$(echo "$1" | cut -d ':' -f 1)"
GH_CORE=$(echo "$1" | cut -d ':' -f 2)
GH_JSON="/tmp/_curl_git_$COREREP"

#init_git "libretro-cores-update"

pull_json "$GH_CORE" "$GH_JSON"

GH_COMMIT=$(jq .sha "$GH_JSON" | tr -d \")

cd "$HP_CORE"

#done < ./libretro_cores.list
