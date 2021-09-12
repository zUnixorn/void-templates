#!/bin/bash
#
# deploy.sh

# TODO: remove packages if the template doesn't exist anymore

set -e

REPONAME="void-templates"
OWNER="ram02z"
GHIO="${OWNER}.github.io"
TARGET_BRANCH="gh-pages"
EMAIL="omarzeghouanii@gmail.com"
BUILD_DIR="void-packages/hostdir/binpkgs"
case "$ARCH" in
    *musl* ) LIBC="musl" ;;
    * ) LIBC="glibc" ;;
esac

echo "### Started deploy to $GITHUB_REPOSITORY/$TARGET_BRANCH"

# Prepare build_dir
mkdir -p $HOME/build/$BUILD_DIR
cp -R $BUILD_DIR/* $HOME/build/$BUILD_DIR/

# Create or clone the gh-pages repo
mkdir -p $HOME/branch/
cd $HOME/branch/
git config --global user.name "$GITHUB_ACTOR"
git config --global user.email "$INPUT_EMAIL"

# Sleep to ensure that latest copy is cloned
if [ "$LIBC" == "musl" ]; then
    sleep 120
fi

if [ -z "$(git ls-remote --heads https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git ${TARGET_BRANCH})" ]; then
  echo "Create branch '${TARGET_BRANCH}'"
  git clone --quiet https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git $TARGET_BRANCH > /dev/null
  cd $TARGET_BRANCH
  git checkout --orphan $TARGET_BRANCH
  git rm -rf .
  echo "$REPONAME" > README.md
  git add README.md
  git commit -a -m "Create '$TARGET_BRANCH' branch"
  git push origin $TARGET_BRANCH
  cd ..
else
  echo "Clone branch '${TARGET_BRANCH}'"
  git clone --quiet --branch=$TARGET_BRANCH https://${GITHUB_ACTOR}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git $TARGET_BRANCH > /dev/null
fi

# Delete old packages
cd $TARGET_BRANCH
find . -maxdepth 1 -type f -delete
mkdir -p $LIBC
PKGS=$(cat /tmp/templates)
for pkg in ${PKGS}; do
	find $LIBC -name "$pkg*" -maxdepth 1 -delete
done

# Delete old signatures and repodata
find $LIBC -name "*.sig" -maxdepth 1 -delete
find $LIBC -name "$ARCH-repodata" -maxdepth 1 -delete
cp -Rf $HOME/build/$BUILD_DIR/*.xbps $LIBC

# Sign packages
xbps-rindex --privkey private.pem --sign --signedby "Omar Zeghouani" $LIBC
xbps-rindex --privkey private.pem --sign-pkg $LIBC/*.xbps

# Generate homepage
cat << EOF > index.html
<html>
<head><title>Index of /$REPONAME</title></head>
<body>
<h1>Index of /$REPONAME</h1>
<hr><pre><a href="https://ram02z.github.io">../</a>
EOF

for d in */; do
    dir=$(basename $d)
    size=$(du -s $d | awk '{print $1;}')
    s=$(stat -c %y $d)
    stat=${s%%.*}

    if [ -d "$d" ]; then
        printf '<a href="%s">%-40s%35s%20s\n' "$dir" "$dir</a>" "$stat" "$size" >> index.html
    fi
done

cat << EOF >> index.html
</pre><hr></body>
</html>
EOF

# TODO: generate index for packages

COMMIT_MESSAGE="$GITHUB_ACTOR published a site update"

# Deploy/Push (or not?)
if [ -z "$(git status --porcelain)" ]; then
  result="Nothing to deploy"
else
  git add -Af .
  git commit -m "$COMMIT_MESSAGE"
  git push -fq origin $TARGET_BRANCH > /dev/null
  # push is OK?
  if [ $? = 0 ]
  then
    result="Deploy succeeded"
  else
    result="Deploy failed"
  fi
fi

# Set output
echo $result
echo "::set-output name=result::$result"

echo "### Finished deploy"