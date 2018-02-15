#!/bin/bash

wd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
die() { echo "$*" 1>&2 ; exit 1; }

sleep 1
$wd/dead_master.sh &
sleep 1
$wd/spawn.sh &
die "roulette KaBoom"
