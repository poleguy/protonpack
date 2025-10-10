#!/usr/bin/env bash

# source this script

# hackity hack. This must be exported to work in the deploy_artifactory script
# we expect to start in the workspace director of slurm
# this must be mounted via sshfs to get the secure keys
# todo: replace this with direct access to PMP or other vault tool
export WORKDIR='/misc/scratch/dietzn/dpsm_rx_slurm'
if [ ! -d $WORKDIR ]; then
  sshfs haydn.shurelab.com:/misc/scratch /misc/scratch
fi

export ARTIFACTORY_KEY=$(cat $WORKDIR/artifactory_key.txt)
export PMP_API_KEY=$(cat $WORKDIR/pmp_api_key.txt)
