#!/bin/sh

source "${JBOSS_CONTAINER_MAVEN_S2I_MODULE}/maven-s2i"

# initialize the module
maven_s2i_init

# persist the artifacts
maven_s2i_save_artifacts > $JBOSS_CONTAINER_WILDFLY_S2I_GALLEON_DIR/m2-incremental.tar

TAR_CONTENT=$JBOSS_CONTAINER_WILDFLY_S2I_GALLEON_DIR/tar-content
mkdir -p "$TAR_CONTENT"

# add maven artifacts if any
if [ -s $JBOSS_CONTAINER_WILDFLY_S2I_GALLEON_DIR/m2-incremental.tar ]; then
  pushd "$TAR_CONTENT" &> /dev/null
  tar -xf $JBOSS_CONTAINER_WILDFLY_S2I_GALLEON_DIR/m2-incremental.tar &> /dev/null
  popd &> /dev/null
fi

source "${JBOSS_CONTAINER_WILDFLY_S2I_MODULE}/galleon/s2i_galleon"

# persist galleon artifacts if any
galleon_build_repo_diff "$TAR_CONTENT"

if [ -n "$TAR_CONTENT" -a -n "$(find ${TAR_CONTENT} -maxdepth 0 -type d ! -empty 2> /dev/null)" ]; then
  pushd "$TAR_CONTENT" &> /dev/null
  tar chf - *
  popd &> /dev/null
fi
rm -rf $JBOSS_CONTAINER_WILDFLY_S2I_GALLEON_DIR/m2-incremental.tar $TAR_CONTENT &> /dev/null
