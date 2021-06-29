#!/usr/bin/env bats

source $BATS_TEST_DIRNAME/../added/launch/files.sh
setup() {
  # setup mock local cache
  GALLEON_LOCAL_MAVEN_REPO=$(mktemp -d)
  #setup mock JBOSS_HOME
  JBOSS_HOME=$(mktemp -d)
  echo JBOSS_HOME $JBOSS_HOME
  echo GALLEON_LOCAL_MAVEN_REPO $GALLEON_LOCAL_MAVEN_REPO

  create_module_m1
  create_module_in_jboss_home
}

teardown() {
  rm -rf $GALLEON_LOCAL_MAVEN_REPO
  rm -rf $JBOSS_HOME
}

create_module_descriptor() {
abs_module_dir="$JBOSS_HOME/modules/system/layers/base/$1"
mkdir -p "$abs_module_dir"
cat > "$abs_module_dir/module.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<module name="$2" xmlns="urn:jboss:module:1.8">
    <resources>
        $3
    </resources>
</module>
EOF
}

create_jar_file() {
  group=$1
  artifact=$2
  version=$3
  jarPath=$group/$artifact/$version/$artifact-$version.jar
  dirName=$(dirname "${jarPath}")
  mkdir -p "$GALLEON_LOCAL_MAVEN_REPO/$dirName"
  touch "$GALLEON_LOCAL_MAVEN_REPO/$jarPath"
}

create_module_m1() {
  artifacts=$(cat <<EOF
<artifact name="org.foo:bar:1.0.0.Final"/>
<artifact name="org.foo:bar:2.0.0.Final"/>
<artifact name="com.foo:bar:3.0.0.Final"/>
<artifact name="org.foo:boo.been:1.0.0.Final"/>
EOF
)
  create_jar_file org/foo bar 1.0.0.Final
  create_jar_file org/foo bar 2.0.0.Final
  create_jar_file com/foo bar 3.0.0.Final
  create_jar_file org/foo boo.been 1.0.0.Final

  create_module_descriptor "org/jboss/as/m1/main" "m1"  "$artifacts"
}

create_module_in_jboss_home() {
  create_module_descriptor "org/jboss/as/m3/main" "m3"
  touch "$JBOSS_HOME/modules/system/layers/base/org/jboss/as/m3/main/local-1.0.jar"
}

@test "getfiles: Should retrieve single jar file starting with boo. from local cache" {
  result=$(getfiles org/jboss/as/m1/main/boo.)
  echo "$result"
  [ "$result" = "$GALLEON_LOCAL_MAVEN_REPO/org/foo/boo.been/1.0.0.Final/boo.been-1.0.0.Final.jar" ]
}

@test "getfiles: Should retrieve single jar file starting with bar-1 from local cache" {
  result=$(getfiles org/jboss/as/m1/main/bar-1)
  echo "$result"
  [ "$result" = "$GALLEON_LOCAL_MAVEN_REPO/org/foo/bar/1.0.0.Final/bar-1.0.0.Final.jar" ]
}

@test "getfiles: Should retrieve single jar file from local cache with full name" {
  result=$(getfiles org/jboss/as/m1/main/bar-1.0.0.Final.jar)
  echo "$result"
  [ "$result" = "$GALLEON_LOCAL_MAVEN_REPO/org/foo/bar/1.0.0.Final/bar-1.0.0.Final.jar" ]
}

@test "getfiles: Should retrieve single jar file starting with bar-2 from local cache" {
  result=$(getfiles org/jboss/as/m1/main/bar-2)
  echo "$result"
  [ "$result" = "$GALLEON_LOCAL_MAVEN_REPO/org/foo/bar/2.0.0.Final/bar-2.0.0.Final.jar" ]
}

@test "getfiles: Should retrieve all jar files from local cache directory" {
  result=$(getfiles org/jboss/as/m1/main/)
  echo "$result"
  [ "$result" = "$GALLEON_LOCAL_MAVEN_REPO/org/foo/bar/1.0.0.Final/bar-1.0.0.Final.jar:\
$GALLEON_LOCAL_MAVEN_REPO/org/foo/bar/2.0.0.Final/bar-2.0.0.Final.jar:\
$GALLEON_LOCAL_MAVEN_REPO/com/foo/bar/3.0.0.Final/bar-3.0.0.Final.jar:\
$GALLEON_LOCAL_MAVEN_REPO/org/foo/boo.been/1.0.0.Final/boo.been-1.0.0.Final.jar" ]
}

@test "getfiles: Should retrieve all jar files starting with bar from local cache" {
  result=$(getfiles org/jboss/as/m1/main/bar)
  echo "$result"
  [ "$result" = "$GALLEON_LOCAL_MAVEN_REPO/org/foo/bar/1.0.0.Final/bar-1.0.0.Final.jar:\
$GALLEON_LOCAL_MAVEN_REPO/org/foo/bar/2.0.0.Final/bar-2.0.0.Final.jar:\
$GALLEON_LOCAL_MAVEN_REPO/com/foo/bar/3.0.0.Final/bar-3.0.0.Final.jar" ]
}

@test "getfiles: Should retrieve all jar files starting with b from local cache" {
  result=$(getfiles org/jboss/as/m1/main/b)
  echo "$result"
  [ "$result" = "$GALLEON_LOCAL_MAVEN_REPO/org/foo/bar/1.0.0.Final/bar-1.0.0.Final.jar:\
$GALLEON_LOCAL_MAVEN_REPO/org/foo/bar/2.0.0.Final/bar-2.0.0.Final.jar:\
$GALLEON_LOCAL_MAVEN_REPO/com/foo/bar/3.0.0.Final/bar-3.0.0.Final.jar:\
$GALLEON_LOCAL_MAVEN_REPO/org/foo/boo.been/1.0.0.Final/boo.been-1.0.0.Final.jar" ]
}

@test "getfiles: Should fail retrieve jar file from non existent prefix" {
  run getfiles org/jboss/as/m1/main/foo
  [ "$status" -eq 1 ]
}

@test "getfiles: Should fail retrieve jar file from non existent dir" {
  run getfiles org/jboss/as/m2/main
  [ "$status" -eq 1 ]
}

@test "getfiles: Should retrieve jar file from JBOSS_HOME" {
  result=$(getfiles org/jboss/as/m3/main/)
  echo "$result"
  [ "$result" = "$JBOSS_HOME/modules/system/layers/base/org/jboss/as/m3/main/local-1.0.jar" ]
}

@test "getfiles: Should retrieve jar file starting with loc from JBOSS_HOME" {
  result=$(getfiles org/jboss/as/m3/main/loc)
  echo "$result"
  [ "$result" = "$JBOSS_HOME/modules/system/layers/base/org/jboss/as/m3/main/local-1.0.jar" ]
}