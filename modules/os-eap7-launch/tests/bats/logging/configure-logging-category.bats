#!/usr/bin/env bats

# bug in bats with set -eu?
export BATS_TEST_SKIPPED=

export JBOSS_HOME=$BATS_TMPDIR/jboss_home
export CONFIG_FILE=$JBOSS_HOME/standalone/configuration/standalone-openshift.xml

mkdir -p $JBOSS_HOME/bin/launch
echo $BATS_TEST_DIRNAME
cp $BATS_TEST_DIRNAME/../../../../test-common/logging.sh $JBOSS_HOME/bin/launch
cp $BATS_TEST_DIRNAME/../../../added/launch/configure_logger_category.sh $JBOSS_HOME/bin/launch
source $BATS_TEST_DIRNAME/../../../added/launch/configure_logger_category.sh

setup() {
  mkdir -p $JBOSS_HOME/standalone/configuration
  cp $BATS_TEST_DIRNAME/../../../../os-eap71-openshift/added/standalone-openshift.xml $JBOSS_HOME/standalone/configuration
}

teardown() {
  rm -rf $JBOSS_HOME
}

# note the <test>...</test> wrapper is used to allow xmllint to reformat (it requires a root node) so comparisons are more robust between different versions
# of xmllint etc.


@test "Add 1 logger category" {
  #this is the return of xmllint --xpath "//*[local-name()='subsystem']//*[local-name()='logger']" $CONFIG_FILE
  expected=$(cat <<EOF
<logger category="com.arjuna"><level name="WARN"/></logger>
<logger category="org.jboss.as.config"><level name="DEBUG"/></logger>
<logger category="sun.rmi"><level name="WARN"/></logger>
<logger category="com.my.package"><level name="DEBUG"/></logger>
EOF
)
  LOGGER_CATEGORIES=com.my.package:DEBUG
  run add_logger_category
  result=$(xmllint --xpath "//*[local-name()='subsystem']//*[local-name()='logger']" $CONFIG_FILE)
  result="$(echo "<test>${result}</test>" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  expected=$(echo "<test>${expected}</test>" | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "Expected: ${expected}"
  echo "Result: ${result}"
  [ "${result}" = "${expected}" ]
}

@test "Add 2 logger categories" {
  #this is the return of xmllint --xpath "//*[local-name()='subsystem']//*[local-name()='logger']" $CONFIG_FILE
  expected=$(cat <<EOF
<logger category="com.arjuna"><level name="WARN"/></logger>
<logger category="org.jboss.as.config"><level name="DEBUG"/></logger>
<logger category="sun.rmi"><level name="WARN"/></logger>
<logger category="com.my.package"><level name="DEBUG"/></logger>
<logger category="my.other.package"><level name="ERROR"/></logger>
EOF
)
  LOGGER_CATEGORIES=com.my.package:DEBUG,my.other.package:ERROR
  run add_logger_category
  result=$(xmllint -xpath "//*[local-name()='subsystem']//*[local-name()='logger']" $CONFIG_FILE)
  result="$(echo "<test>${result}</test>" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  expected=$(echo "<test>${expected}</test>" | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "Expected: ${expected}"
  echo "Result: ${result}"
  [ "${result}" = "${expected}" ]
}

@test "Add 3 logger categories, one with no log level" {
  #this is the return of xmllint --xpath "//*[local-name()='subsystem']//*[local-name()='logger']" $CONFIG_FILE
  expected=$(cat <<EOF
<logger category="com.arjuna"><level name="WARN"/></logger>
<logger category="org.jboss.as.config"><level name="DEBUG"/></logger>
<logger category="sun.rmi"><level name="WARN"/></logger>
<logger category="com.my.package"><level name="DEBUG"/></logger>
<logger category="my.other.package"><level name="ERROR"/></logger>
<logger category="my.another.package"><level name="FINE"/></logger>
EOF
)
  LOGGER_CATEGORIES=com.my.package:DEBUG,my.other.package:ERROR,my.another.package
  run add_logger_category
  result=$(xmllint --xpath "//*[local-name()='subsystem']//*[local-name()='logger']" $CONFIG_FILE)
  result="$(echo "<test>${result}</test>" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  expected=$(echo "<test>${expected}</test>" | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "Expected: ${expected}"
  echo "Result: ${result}"
  [ "${result}" = "${expected}" ]
}

@test "Add 3 logger categories with spaces" {
  #this is the return of xmllint --xpath "//*[local-name()='subsystem']//*[local-name()='logger']" $CONFIG_FILE '
  expected=$(cat <<EOF
<logger category="com.arjuna"><level name="WARN"/></logger>
<logger category="org.jboss.as.config"><level name="DEBUG"/></logger>
<logger category="sun.rmi"><level name="WARN"/></logger>
<logger category="com.my.package"><level name="DEBUG"/></logger>
<logger category="my.other.package"><level name="ERROR"/></logger>
<logger category="my.another.package"><level name="FINE"/></logger>
EOF
)
  LOGGER_CATEGORIES=" com.my.package:DEBUG, my.other.package:ERROR, my.another.package"
  run add_logger_category
  result=$(xmllint --xpath "//*[local-name()='subsystem']//*[local-name()='logger']" $CONFIG_FILE)
  result="$(echo "<test>${result}</test>" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  expected=$(echo "<test>${expected}</test>" | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "Expected: ${expected}"
  echo "Result: ${result}"
  [ "${result}" = "${expected}" ]
}

@test "Add 2 logger categories one with invalid log level" {
  #this is the return of xmllint --xpath "//*[local-name()='subsystem']//*[local-name()='logger']" $CONFIG_FILE
  expected=$(cat <<EOF
<logger category="com.arjuna"><level name="WARN"/></logger>
<logger category="org.jboss.as.config"><level name="DEBUG"/></logger>
<logger category="sun.rmi"><level name="WARN"/></logger>
<logger category="com.my.package"><level name="DEBUG"/></logger>
EOF
)
  LOGGER_CATEGORIES=com.my.package:DEBUG,my.other.package:UNKNOWN_LOG_LEVEL
  run add_logger_category
  result=$(xmllint --format --noblanks --xpath "//*[local-name()='subsystem']//*[local-name()='logger']" $CONFIG_FILE)
  result="$(echo "<test>${result}</test>" | sed 's|\\n||g' | xmllint --format --noblanks -)"
  expected=$(echo "<test>${expected}</test>" | sed 's|\\n||g' | xmllint --format --noblanks -)
  echo "Expected: ${expected}"
  echo "Result: ${result}"
  [ "${result}" = "${expected}" ]
}
