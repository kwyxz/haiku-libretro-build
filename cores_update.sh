#!/bin/sh

# functions
die () {
  echo -e "\033[31mERROR:\e[0m $1"
  exit 1
}

clean_tmp () {
  echo -e "\033[32mCleaning\e[0m /tmp"
  rm -f /tmp/_curl_git_*
  rm -f /tmp/*.list
}

init_git () {
  git checkout master
  git push origin --delete "$1"
  git branch -D "$1"
  git checkout -b "$1"
  git push origin "$1"
}

create_git () {
  # remove pre-existing branch and create new one
  echo -e "\033[32mCreating branch\e[0m $1"
  git checkout "$2"
  git branch -D "$1"
  git checkout -b "$1"
}

delete_git () {
  echo -e "\033[31mDeleting branch\e[0m $1"
  git commit -a -m "FAIL"
  git checkout "$2"
  git branch -D "$1"
}

merge_git () {
  # merge changes
  echo -e "\033[32mMerging into main dev branch\e[0m $1"
  git commit -a -m "$1: bumped to version $2"
  git checkout "$3"
  git merge "$1"
#  git merge --squash "$1"
}

push_git () {
  # push changes
  git checkout "$1"
  git commit -a -m "Multiple updates to libretro cores"
  git push origin "$1"
}

pull_json () {
  # pull JSON for latest commit
  echo -e "\033[32mPulling JSON for\e[0m $1"
  curl -k -H "Authorization: bearer ${GH_TOKEN}" -H "Content-type: application/json" -s "https://api.github.com/repos/libretro/$1/commits/refs/heads/master" -o "$2"
}

build_package () {
  echo -e "\033[32mBuild package\e[0m $1"
  HP=$(command -v haikuporter)
  $HP -S -j8 --get-dependencies --no-source-packages "$1"
  test $? -eq 0 || echo "$1" >> $RUNDIR/failed_builds.log
}

HP_PATH="/boot/home/haikuports"
RUNDIR=$(pwd)

# a github_auth file is necessary in this folder to identify to 
# GitHub and its contents should be :
# GH_TOKEN=<token>
source "$RUNDIR/github_auth"

if [ -z "$1" ]
then
  die "no list argument given"
fi

BRANCH_NAME=$(basename $1 .list)

clean_tmp
rm $RUNDIR/failed_builds.log

grep -v ^\# "$1" > "/tmp/$BRANCH_NAME.list"

cd "$HP_PATH"
init_git "$BRANCH_NAME"

while IFS= read -r COREFOLDER
do

  HP_CORE=$(echo "$COREFOLDER" | cut -d ':' -f 1)
  HP_CORE_NAME=$(echo "$HP_CORE" | cut -d '/' -f 2)
  HP_CORE_FOLDER=$(echo "$HP_PATH"/"$HP_CORE")
  GH_CORE=$(echo "$COREFOLDER" | cut -d ':' -f 2)
  GH_JSON="/tmp/_curl_git_$GH_CORE"

  pull_json "$GH_CORE" "$GH_JSON"

  GH_COMMIT=$(jq .sha "$GH_JSON" | tr -d \")
  GH_DATE=$(jq .commit.author.date "$GH_JSON" | cut -d 'T' -f 1 | tr -d "-" | tr -d \")
  HP_RECIPE=$(ls -1 "$HP_CORE_FOLDER"/*.recipe)
  HP_COMMIT=$(grep ^srcGitRev "$HP_CORE_FOLDER"/*.recipe | cut -d '=' -f 2 | tr -d \")
  HP_VERSION=$(basename "$HP_RECIPE" | cut -d '-' -f 2 | cut -d '_' -f 1 | sed -e 's/\.recipe//')
  HP_CORE_DL=$(echo "$HP_CORE_FOLDER/download")
  HP_CORE_ARCHIVE=$(echo "$HP_CORE_DL/$GH_CORE-$HP_VERSION-$GH_DATE-$GH_COMMIT.tar.gz")
  HP_CORE_PACKAGE=$(echo "$HP_CORE_NAME"-"$HP_VERSION"_"$GH_DATE")

  if [ "$GH_COMMIT" == "$HP_COMMIT" ];
  then
    echo -e "\033[33mNo need to update core\e[0m $GH_CORE."
  else
    create_git "$HP_CORE_NAME" "$BRANCH_NAME"
    echo -e "\033[32mUpdating core\e[0m $GH_CORE"
    rm -rf "$HP_CORE_FOLDER/work-*"
    mkdir -p "$HP_CORE_DL"
    wget "https://github.com/libretro/$GH_CORE/archive/$GH_COMMIT.tar.gz" -O "$HP_CORE_ARCHIVE"
    GH_SHA256SUM=$(sha256sum "$HP_CORE_ARCHIVE" | awk '{print $1}')
    sed -i -e s/^REVISION=\".\"/REVISION=\"1\"/ "$HP_RECIPE"
    sed -i -e s/^CHECKSUM_SHA256=\".*\"/CHECKSUM_SHA256=\"$GH_SHA256SUM\"/ "$HP_RECIPE"
    sed -i -e s/^srcGitRev=\".*\"/srcGitRev=\"$GH_COMMIT\"/ "$HP_RECIPE"
    git mv "$HP_RECIPE" "$HP_CORE_FOLDER/$HP_CORE_PACKAGE.recipe"
    if [ -d "$HP_CORE_FOLDER/patches" ];
    then
      HP_PATCHFILE=$(ls -1 "$HP_CORE_FOLDER"/patches/*.patchset)
      git mv "$HP_PATCHFILE" "$HP_CORE_FOLDER/patches/$HP_CORE_PACKAGE.patchset"
    fi
    build_package "$HP_CORE_NAME"
    if [ -f "$HP_PATH/packages/$HP_CORE_PACKAGE-1-x86_64.hpkg" ]
    then
      echo -e "\033[32mSUCCESS:\e[0m $HP_CORE bumped to $HP_VERSION:$GH_DATE" >> "/tmp/$BRANCH_NAME.log"
      merge_git "$HP_CORE_NAME" "$HP_VERSION:$GH_DATE" "$BRANCH_NAME"
      delete_git "$HP_CORE_NAME" "$BRANCH_NAME"
    else
      echo -e "\033[33mFAILED:\e[0m $HP_CORE" >> "/tmp/$BRANCH_NAME.log"
      delete_git "$HP_CORE_NAME" "$BRANCH_NAME"
    fi
  fi
done < "/tmp/$BRANCH_NAME.list"

push_git "$BRANCH_NAME"
exit 0
