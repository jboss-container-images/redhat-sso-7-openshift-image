#!/bin/sh
function listjars {
  FILES=$(ls $1*.jar)
  echo ${FILES}
}

function getfiles_from_module_artifacts {
  moduleDir=$1
  if [ -f $moduleDir/module.xml ]; then
    files="$(get_maven_artifacts_jar $moduleDir/module.xml $2)"
    if [ -n "$files" ]; then
      echo "$files"
    fi
  fi
}

function get_maven_artifacts_jar {
  moduleFile=$1
  incomplete=$2
  artifacts="$(xmllint --xpath "//*[local-name()='module']/*[local-name()='resources']/*[local-name()='artifact']/@name" $moduleFile 2>/dev/null)"

  readarray ARR <<< "${artifacts}"
  for i in "${ARR[@]}"; do
    v="$(echo $i | grep -o '\".*\"')"
    f=${v/\"/}
    clean=${f%%\"}
    IFS=':'
    read -ra GAV <<< "$clean"
    groupIdPath=${GAV[0]//./\/}
    jarFile=$GALLEON_LOCAL_MAVEN_REPO/$groupIdPath/${GAV[1]}/${GAV[2]}/${GAV[1]}-${GAV[2]}.jar
    #echo $jarFile
    if [ -f $jarFile ]; then
      #echo jar file exist
      if [ -n "$incomplete" ]; then
        jarFileName=$(basename "${jarFile}")
        #echo test $jarFileName startsWith $fname
        if [[ ${jarFileName} =~ ^${incomplete} ]]; then   
          #echo "$jarFileName" startsWith $incomplete
          if [ ! -z $ret ]; then
            ret="$ret "
          fi
          ret="$ret$jarFile"
        fi
      else
        if [ ! -z $ret ]; then
          ret="$ret "
        fi
        ret="$ret$jarFile"
      fi
    fi
    IFS=' '
  done
  if [ -n "$ret" ]; then
    echo "$ret" | sed -e "s| |:|g"
  fi
}

function getfiles {
  OVERLAYS_PATH="$JBOSS_HOME/modules/system/layers/base/.overlays"
  MODULES_SOURCE_PATHS=("$JBOSS_HOME/modules/system/layers/base" "$JBOSS_HOME")

  # Did we apply any patches?
  if [ -f "$OVERLAYS_PATH/.overlays" ]; then
    # Yes, we did!
    # Use tac to reverse the content in the .overlays file
    for layer in $(tac $OVERLAYS_PATH/.overlays); do
      # Add the overlay to the list of modules sources
      MODULES_SOURCE_PATHS=("$OVERLAYS_PATH/$layer" ${MODULES_SOURCE_PATHS[@]})
    done
  fi

  name=$1

  for source_dir in "${MODULES_SOURCE_PATHS[@]}"; do
    if [ -d "$source_dir/${name}" ]; then
      files="$(listjars $source_dir/${name})"

      if [ -n "$files" ]; then
        echo "$files" | sed -e "s/^[ \t]*//" | sed -e "s| |:|g" | sed -e ":a;N;$!ba;s|\n|:|g"
        return
      else
        # Could be a slim installation with jars in maven repository
        files="$(getfiles_from_module_artifacts $source_dir/${name})"
        if [ -n "$files" ]; then
          echo "${files}"
          return
        fi
      fi
    else
      files="$(compgen -G "$source_dir/${name}*.jar")"

      if [ -n "$files" ]; then
        echo "${files[0]}"
        return
      else
        # Could be a slim installation with jars in maven repository
        dir="$(dirname $source_dir/${name})"
        fname="$(basename $source_dir/${name})"
        files="$(getfiles_from_module_artifacts $dir $fname)"
        if [ -n "$files" ]; then
          echo "${files}"
          return
        fi
      fi
    fi
  done

  echo "Could not find any jar for the $name path, aborting"
  exit 1
}
