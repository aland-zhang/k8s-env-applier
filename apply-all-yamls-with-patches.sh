#!/bin/bash

usage(){
# =============================================================================
cat << EndOfUsage

This script applies all the YAML files in the current dir and environment
specific patches. It also sets the image for one container.

Processing takes place in the following order:
1. Environment specific YAML files
2. Common YAML files
2.1. For each common YAML file a json patch is applied,
2.2. followed by a merge patch, before
3. the result is applied to the environment.

Important: Exactly one object per YAML file is expected.

Usage:
With parameters
  $ ${0##*/} <name-space> <env-patch-dir> [<image-to-update> <new-image-tag>]

With environment variables
  $ ${0##*/}

  Mandatory environment variables:
  - NAMESPACE
  - ENV_PATCHES_DIR

  Optional environment variables:
  - IMAGE_TO_UPDATE
  - NEW_IMAGE_TAG
EndOfUsage
exit 1
# =============================================================================
}

parseParameters(){
  if [[ $# -eq  4 ]]
  then
    NAMESPACE=$1
    ENV_PATCHES_DIR=$2
    IMAGE_TO_UPDATE=$3
    NEW_IMAGE_TAG=$4
  elif [[ $# -eq  2 ]]
  then
    NAMESPACE=$1
    ENV_PATCHES_DIR=$2
  elif [[ $# -eq 0 ]]
  then
    [[ -z ${NAMESPACE} || -z ${ENV_PATCHES_DIR} ]] && usage
    [[ -z ${IMAGE_TO_UPDATE} && -z ${NEW_IMAGE_TAG} || ! -z ${IMAGE_TO_UPDATE} && ! -z ${NEW_IMAGE_TAG} ]] || usage
  else
    usage
  fi
}
parseParameters $@

cat << EndOfConfig
Configuration in use:
* Working dir `pwd`
- NAMESPACE=${NAMESPACE}
- ENV_PATCHES_DIR=${ENV_PATCHES_DIR}
- IMAGE_TO_UPDATE=${IMAGE_TO_UPDATE}
- NEW_IMAGE_TAG=${NEW_IMAGE_TAG}

EndOfConfig

set -o errexit

# =============================================================================
# Patch the given resource
#
# This function expects exactly zero or one json patch file with the form
# "patch-resource-name.json", and exactly zero or one merge patch file with the
# form "patch-resource-name.yaml"
# The json file, if present, is applied in a json patch, and the yaml file, if
# present, is applied in a merge patch.
#
# Parameters:
# - patchesDir: The directory where patches will be applied
# - resource: The resource to patch
# - tempYamlFilename: The name of the file containing the YAML being processed
# =============================================================================
patchK8sResource(){
  patchesDir=$1
  resourceName=$2
  tempYamlFilename=$3

  if [[ -e "${patchesDir}/patch-${resourceName}.json" ]]
  then
    echo "APPLYING json patch ${patchesDir}/patch-${resourceName}.json"
    cat ${tempYamlFilename} | \
      kubectl patch --namespace ${NAMESPACE} --type json --patch "$(cat "${patchesDir}/patch-${resourceName}.json")" --output yaml --local -f - \
        > ${tempYamlFilename}
  fi
  if [[ -e "${patchesDir}/patch-${resourceName}.yaml" ]]
  then
    echo "APPLYING merge patch ${patchesDir}/patch-${resourceName}.yaml"
    cat ${tempYamlFilename} | \
      kubectl patch --namespace ${NAMESPACE} --type merge --patch "$(cat "${patchesDir}/patch-${resourceName}.yaml")" --output yaml --local -f - \
        > ${tempYamlFilename}
  fi

  if [[ ! -e "${patchesDir}/patch-${resourceName}.json" && ! -e "${patchesDir}/patch-${resourceName}.yaml" ]]
  then
    echo "NO patches for ${resourceName}"
  fi

  cat "${tempYamlFilename}" | kubectl apply --namespace ${NAMESPACE} -f -
}

# =============================================================================
# Search and replace the image with a new tag, if found
#
# Parameters:
# - imageToUpdateName: The name of the image to be updated with a new tag
# - newTagName: The new image tag
# - tempYamlFilename: The name of the file containing the YAML being processed
# =============================================================================
replaceContainerImageIfFound(){
  imageToUpdateName=$1
  newTagName=$2
  tempYamlFilename=$3

  [[ ! -z ${imageToUpdateName} && ! -z ${newTagName} && ! -z ${tempYamlFilename} ]] && \
    sed -i 's|image:[ *]'"${imageToUpdateName}"':.*$|image: '"${imageToUpdateName}"':'"${newTagName}"'|' ${tempYamlFilename} || \
    true
}

# =============================================================================
# Loop through each environment specific YAML file and apply it
#
# Parameters:
# - patchesDir: The directory where environment specific YAML files will be applied
# =============================================================================
doApplyAllEnvSpecificYaml(){
  patchesDir=$1
  appliedPatchCount=0
  files=$(shopt -s nullglob dotglob; echo ${patchesDir}/*.yaml)

  for yamlFile in ${files}
  do
    if [[ ${yamlFile} != ${patchesDir}/patch-* ]]
    then
      ((++appliedPatchCount))
      echo "APPLYING YAML ${yamlFile}"
      kubectl apply --namespace ${NAMESPACE} -f "${yamlFile}"
      echo
    fi
  done

  if [[ ${appliedPatchCount} -eq 0 ]]
  then
    echo "NO environment specific YAML files to apply"
    echo
  fi
}

# =============================================================================
# Loop through each YAML file and apply it with patches
#
# This function expects exactly one object per YAML file
#
# Parameters:
# - patchesDir: The directory where patches will be applied
# - imageToUpdateName: The name of the image to be updated with a new tag
# - newTagName: The new image tag
# =============================================================================
doApplyAllYaml(){
  patchesDir=$1
  imageToUpdateName=$2
  newTagName=$3

  # Always clean up
  trap "rm -f temp; exit" INT TERM EXIT

  for yamlFile in *.yaml
  do
    echo "UPDATING ${yamlFile%.yaml}"
    cp ${yamlFile} temp
    replaceContainerImageIfFound ${imageToUpdateName} ${newTagName} temp
    patchK8sResource "${patchesDir}" "${yamlFile%.yaml}" temp
    echo
  done
}

doApplyAllEnvSpecificYaml ${ENV_PATCHES_DIR}
doApplyAllYaml ${ENV_PATCHES_DIR} ${IMAGE_TO_UPDATE} ${NEW_IMAGE_TAG}
