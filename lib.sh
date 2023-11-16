#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2020 Jakub Kicinski <kuba@kernel.org>

red()
{
  echo -n -e "\e[1;31m$@"
  [ ! -z "$@" ] && echo -n -e "\e[0m"
}

bold()
{
  echo -n -e "\e[1m$@"
  [ ! -z "$@" ] && echo -n -e "\e[0m"
}

normal()
{
  echo -n -e "\e[0m$@"
}

pr_trunc_n()
{
  local len=$1
  local str="$2"

  if [ ${#str} -le $len ]; then
    echo -n "$str"
  else
    echo -n ${str::len - 3}...
  fi
}

date_to_hours()
{
  local past="$1"

  now=$(date +%s)
  was=$(date -d "$past" +%s)

  echo $(( (now - was) / (60 * 60) ))
}

date_to_age()
{
  local hours=$(date_to_hours $1)
  echo "$((hours / 24))d $((hours % 24))h"
}

subject_remove_tag()
{
  echo "$@" | sed -e 's/\[.*\] *//'
}

subject_get_tree()
{
  tree=$(echo "$@" |
	   sed -n 's/\[\(.*\)\].*/\1/p' |
	   tr , '\n' |
	   sed -n '/[a-z]$/p')
  echo ${tree:--}
}

pw_series_download_mbox()
{
  local	series_json="$1"
  local out_file=${2:-mbox}

  mbox_url=$(echo "$series_json" | jq -r '.mbox')
  curl -s "$mbox_url" > $out_file
}

pw_series_print_short()
{
  local series_json="$1"
  local min_age="$2"

  series_subj=$(echo "$series_json" | jq -r '.name')
  patch_subj=$(echo "$series_json" | jq -r '.patches[0].name')
  cover_letter=$(echo "$series_json" | jq -r '.cover_letter')
  cnt=$(echo "$series_json" | jq -r '.patches | length')
  author=$(echo "$series_json" | jq -r '.submitter.name')
  ver=$(echo "$series_json" | jq -r '.version')
  complete=$(echo "$series_json" | jq -r '.received_all')
  date=$(echo "$series_json" | jq -r '.date')

  date="$date UTC"

  name=$(subject_remove_tag "$series_subj")
  tree=$(subject_get_tree "$patch_subj")
  age=$(date_to_age "$date")
  resend=$(echo "$patch_subj" | sed -n 's/.*resend.*/r/Ip')

  bold "By: $author  Age: $age  Tree: $tree  Version: $ver$resend  Patches: $cnt\n"
  if [ "$complete" != true ]; then
      red
      bold
      echo "WARNING: Series is not complete"
      normal
  fi
  dwd=$(basename $PWD)
  if [[ "$tree" =~ ^(net|bpf)(-next)?$ &&
        "$dwd"  =~ ^(net|bpf)(-next)?$ &&
        "$tree" != "$dwd" ]]; then
      red
      bold
      echo "WARNING: Applying to the wrong tree?"
      normal
  fi
  hours=$(date_to_hours "$date")
  if [ -n "$min_age" -a $hours -lt $min_age ]; then
      red
      bold
      echo "WARNING: series posted < ${min_age}h ago, have reviewers had enough time?"
      normal
  fi
  echo "-----"

  if [ "$cover_letter" != "null" ]; then
    bold
    pr_trunc_n 78 "$name"
    normal "\n"
  fi

  echo "$series_json" |
    jq -r '.patches[].name' |
    while read -r patch_subj; do
      patch_name=$(subject_remove_tag "$patch_subj")
      echo -n "  "
      pr_trunc_n 77 "$patch_name"
      echo
    done

  echo
}

#######################

mbox_from_series()
{
  srv=$(git config --get pw.server)
  srv=${srv%/} # strip trailing slash

  series_json=$(curl -s $srv/series/$1/)

  pw_series_print_short "$series_json" "$2"
  pw_series_download_mbox "$series_json" mbox.i
}
