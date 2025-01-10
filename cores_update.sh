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
  echo -e "\033[32mDeleting branch\e[0m $1"
  git checkout "$2"
  git branch -D "$1"
}

fail_git () {
  echo -e "\033[31mFailing branch\e[0m $1"
  git commit -a -m "FAIL"
  git checkout "$2"
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
  curl -k -H "Authorization: bearer ${GH_TOKEN}" -H "Content-type: application/json" -s "https://api.github.com/repos/${1}/commits/refs/heads/${3}" -o "$2"
}

build_package () {
  echo -e "\033[32mBuild package\e[0m $1"
  HP="/boot/home/haikuporter/haikuporter"
  $HP -S -j8 --get-dependencies --no-source-packages "$1"
  test $? -eq 0 || return 1
}

INFO_FOLDER="/boot/home/libretro-super/dist/info"
HP_PATH="/boot/home/Code/haikuports"
RUNDIR=$(pwd)

# make sure this is installed
pkgman install jq

# a github_auth file is necessary in this folder to identify to 
# GitHub and its contents should be :
# GH_TOKEN=<token>
source "$RUNDIR/github_auth"

if [ -z "$1" ]; then
  die "no list argument given"
fi

BRANCH_NAME=$(basename $1 .list)

clean_tmp
rm $RUNDIR/*.log

grep -v ^\# "$1" > "/tmp/$BRANCH_NAME.list"

cd "$HP_PATH"
init_git "$BRANCH_NAME"

while IFS= read -r COREFOLDER; do

  HP_CORE=$(echo "$COREFOLDER" | cut -d ':' -f 1)
  HP_CORE_NAME=$(echo "$HP_CORE" | cut -d '/' -f 2)
  HP_CORE_FOLDER=$(echo "$HP_PATH"/"$HP_CORE")
  GH_CORE=$(echo "$COREFOLDER" | cut -d ':' -f 2)
  GH_REPO=$(echo "$GH_CORE" | cut -d '/' -f 1)
  GH_CORE_STRIPPED=$(echo "$GH_CORE" | cut -d '/' -f 2)
  GH_JSON="/tmp/_curl_git_${GH_CORE_STRIPPED}"
  GH_BRANCH=$(echo "$COREFOLDER" | cut -d ':' -f 3)

  pull_json "$GH_CORE" "$GH_JSON" "$GH_BRANCH"

  GH_COMMIT=$(jq .sha "$GH_JSON" | tr -d \")
  GH_DATE=$(jq .commit.author.date "$GH_JSON" | cut -d 'T' -f 1 | tr -d "-" | tr -d \")
  HP_RECIPE=$(ls -1 "$HP_CORE_FOLDER"/*.recipe)
  HP_COMMIT=$(grep ^srcGitRev "$HP_CORE_FOLDER"/*.recipe | cut -d '=' -f 2 | tr -d \")
  HP_VERSION=$(basename "$HP_RECIPE" | cut -d '-' -f 2 | cut -d '_' -f 1 | sed -e 's/\.recipe//')
  HP_CORE_DL=$(echo "$HP_CORE_FOLDER/download")
  HP_CORE_ARCHIVE=$(echo "$HP_CORE_DL/$GH_CORE_STRIPPED-$HP_VERSION-$GH_DATE-$GH_COMMIT.tar.gz")
  HP_CORE_PACKAGE=$(echo "$HP_CORE_NAME"-"$HP_VERSION"_"$GH_DATE")

  if [ "$GH_COMMIT" == "$HP_COMMIT" ]; then
    echo -e "\033[33mNo need to update core\e[0m ${GH_CORE_STRIPPED}."
  else
    create_git "$HP_CORE_NAME" "$BRANCH_NAME"
    echo -e "\033[32mUpdating core\e[0m $GH_CORE_STRIPPED"
    rm -rf "$HP_CORE_FOLDER/work-*"
    mkdir -p "$HP_CORE_DL"
    wget "https://github.com/$GH_CORE/archive/$GH_COMMIT.tar.gz" -O "$HP_CORE_ARCHIVE"
    sed -i -e s/^SOURCE_URI=\".*\"/SOURCE_URI=\"https\:\\/\\/github.com\\/${GH_REPO}\\/${GH_CORE_STRIPPED}\\/archive\\/\$srcGitRev\.tar\.gz\"/ "$HP_RECIPE"
    GH_SHA256SUM=$(sha256sum "$HP_CORE_ARCHIVE" | awk '{print $1}')
    sed -i -e s/^REVISION=\".\"/REVISION=\"1\"/ "$HP_RECIPE"
    sed -i -e s/^CHECKSUM_SHA256=\".*\"/CHECKSUM_SHA256=\"$GH_SHA256SUM\"/ "$HP_RECIPE"
    sed -i -e s/^srcGitRev=\".*\"/srcGitRev=\"$GH_COMMIT\"/ "$HP_RECIPE"
    # if there is a patch file it needs to be renamed too
    if [ -d "$HP_CORE_FOLDER/patches" ]; then
      HP_PATCHFILE=$(ls -1 "$HP_CORE_FOLDER"/patches/*.patchset)
      git mv "$HP_PATCHFILE" "$HP_CORE_FOLDER/patches/${HP_CORE_PACKAGE}.patchset"
      sed -i -e s/^PATCHES=\".*\"/PATCHES=\"${HP_CORE_PACKAGE}.patchset\"/ "${HP_RECIPE}"
    fi
    git mv "$HP_RECIPE" "$HP_CORE_FOLDER/$HP_CORE_PACKAGE.recipe"
    if [ ${HP_CORE_NAME} != "retroarch_assets" ] && [ -d ${INFO_FOLDER} ]; then
      sed -e s/^display_version\ =\ \".*\"/display_version\ =\ \"@DISPLAY_VERSION@\"/ ${INFO_FOLDER}/${HP_CORE_NAME}.info > ${HP_CORE_FOLDER}/additional-files/${HP_CORE_NAME}.info.in
    fi
    build_package "$HP_CORE_NAME"
    if [ $? -eq 0 ]; then
      echo -e "\033[32mSUCCESS:\e[0m $HP_CORE bumped to $HP_VERSION:$GH_DATE" >> "${RUNDIR}/${BRANCH_NAME}.log"
      merge_git "$HP_CORE_NAME" "$HP_VERSION:$GH_DATE" "$BRANCH_NAME"
      delete_git "$HP_CORE_NAME" "$BRANCH_NAME"
    else
      echo -e "\033[33mFAILED:\e[0m $HP_CORE" >> "${RUNDIR}/${BRANCH_NAME}.log"
      fail_git "$HP_CORE_NAME" "$BRANCH_NAME"
    fi
  fi
done < "/tmp/$BRANCH_NAME.list"

push_git "$BRANCH_NAME"
exit 0
