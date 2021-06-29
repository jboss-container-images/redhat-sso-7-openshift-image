#!/usr/bin/env bats

source $BATS_TEST_DIRNAME/../artifacts/opt/jboss/container/wildfly/s2i/galleon/s2i_galleon

setup() {
  JBOSS_HOME=$(mktemp -d)
  echo JBOSS_HOME $JBOSS_HOME
  mkdir -p "$JBOSS_HOME/.galleon"
}

teardown() {
  rm -rf $JBOSS_HOME
}

create_provisioning() {
abs_path="$JBOSS_HOME/.galleon/provisioning.xml"
rm -rf "$abs_path"
cat > "$abs_path" << EOF
<?xml version="1.0" ?>
<installation xmlns="urn:jboss:galleon:provisioning:3.0">
    <feature-pack location="wildfly@maven(org.jboss.universe:community-universe):current#18.0.0.Beta1-SNAPSHOT">
        <default-configs inherit="false"/>
        <packages inherit="false"/>
    </feature-pack>
    <options>
        $1
    </options>
</installation>
EOF
cat $abs_path
}

create_slim_installation_1() {
   options=$(cat <<EOF
<option name="optional-packages" value="passive+"/>
<option name="jboss-maven-dist" value="true"/>
EOF
)
  create_provisioning "$options"
}

create_slim_installation_2() {
   options=$(cat <<EOF
<option name="jboss-maven-dist" value="true"/>
EOF
)
  create_provisioning "$options"
}

create_fat_installation_1() {
   options=$(cat <<EOF
<option name="jboss-maven-dist" value="false"/>
EOF
)
  create_provisioning "$options"
}

create_fat_installation_2() {
  create_provisioning 
}

@test "galleon_is_slim_server: slim 1 installation" {
  create_slim_installation_1
  result=$(galleon_is_slim_server)
  echo "$result"
  [ "$result" = "true" ]
}

@test "galleon_is_slim_server: slim 2 installation" {
  create_slim_installation_2
  result=$(galleon_is_slim_server)
  echo "$result"
  [ "$result" = "true" ]
}

@test "galleon_is_slim_server: fat 1 installation" {
  create_fat_installation_1
  result=$(galleon_is_slim_server)
  echo "$result"
  [ "$result" = "false" ]
}

@test "galleon_is_slim_server: fat 2 installation" {
  create_fat_installation_2
  result=$(galleon_is_slim_server)
  echo "$result"
  [ "$result" = "false" ]
}
