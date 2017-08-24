#!/usr/bin/env bash
set -e

RELVER=4.0.7

if [ -x /usr/bin/curl ]; then
  PRETTY_REPOS=(`curl -s "https://api.github.com/orgs/KiCad/repos?per_page=100&page=1" \
    "https://api.github.com/orgs/KiCad/repos?per_page=100&page=2" 2> /dev/null \
    | grep full_name | grep pretty \
    | sed -r  's:.+ "KiCad/(.+)",:\1:'`)
  PRETTY_SRC=(${PRETTY_REPOS[@]})
  PRETTY_SRC=(${PRETTY_SRC[@]/#/https://github.com/KiCad/})
fi

REPOS_NOT_TAGGED=0
NOF_REPOS_TAGGED=0
printf "" > git-dictates.tmp

check_tag() {
  if [[ $(git tag -l $RELVER) ]]; then
    echo "Tag found"
    ((NOF_REPOS_TAGGED+=1))
    echo "$PRETTY_DIR" >> "../git-dictates.tmp"
    git checkout $RELVER
  else
    echo "Tag not found"
    REPOS_NOT_TAGGED="$REPOS_NOT_TAGGED $PRETTY_DIR"
  fi
}

for repo in ${PRETTY_SRC[@]}; do
  PRETTY_DIR="${repo#*KiCad/}"
  echo $PRETTY_DIR
  if [ -e $PRETTY_DIR ]; then
    cd $PRETTY_DIR
    #git pull origin master
    git fetch origin
    check_tag
    cd ..
  else
    git clone $repo
  fi
done

#wget https://raw.githubusercontent.com/KiCad/kicad-library/master/template/fp-lib-table.for-pretty -O fp-lib-table.for-pretty
wget https://raw.githubusercontent.com/KiCad/kicad-library/${RELVER}/template/fp-lib-table.for-pretty -O fp-lib-table.for-pretty

echo "### SUMMARY ###"
echo "Repos to be removed from release tar: $REPOS_NOT_TAGGED"
echo "Repos to be included to the release tar: $NOF_REPOS_TAGGED"
echo -n "Repos expected to be included from the fp-lib-table:"
cat fp-lib-table.for-pretty | grep pretty | awk '{ print $5 }' | sed 's/${KISYSMOD}\///g' | sed 's/)(options//g' | wc -l
cat fp-lib-table.for-pretty | grep pretty | awk '{ print $5 }' | sed 's/${KISYSMOD}\///g' | sed 's/)(options//g' | sort > fp-lib-table-dictates
cat git-dictates.tmp | sort > git-dictates

diff fp-lib-table-dictates git-dictates
if [ $? -ne 0 ]; then
  echo "ERROR: fp-lib-table and git tags does not match"
else
  echo "OK: fp-lib-table and git tags do match perfectly"
  if [ -e kicad-footprints-$RELVER ]; then 
    rm -rf kicad-footprints-$RELVER*
  fi
  mkdir kicad-footprints-$RELVER
  cp -r *.pretty kicad-footprints-$RELVER
  rm -rf kicad-footprints-$RELVER/*.pretty/.git

  echo "Creating tar.gz and zip"
  zip -r kicad-footprints-$RELVER.zip kicad-footprints-$RELVER > /dev/null
  #tar -cJf kicad-footprints-$RELVER.tar.xz kicad-footprints-$RELVER > /dev/null
  tar -zcvf kicad-footprints-$RELVER.tar.gz kicad-footprints-$RELVER > /dev/null
fi
