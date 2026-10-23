#!/bin/bash
# This script is used for collecting exadata machine status as
# Machine, Grid, OS, RDBMS etc.
# -------------------------------------------------------
# Written by Anurag Gupta
opt=$( tr '[:upper:]' '[:lower:]' <<<"$1" )
case $opt in
pre)
echo "Collecting Pre Activity logs ...";
sh /u01/app/oracle/scripts/patching_verify/dbstat $opt >/tmp/dbstat_pre_execution.log 2>&1;
echo "Done";
;;
post)
echo "Collecting Post Activity logs ..."
sh /u01/app/oracle/scripts/patching_verify/dbstat $opt >/tmp/dbstat_post_execution.log 2>&1;
echo "Done";
;;
# status)
# echo "Current status of machine..."
# sh /u01/app/oracle/scripts/patching_verify/dbstat_status $opt |tee /tmp/dbstat_status_execution.log 2>&1;
# echo "Done";
# ;;
*)
echo "OS Level Machine verification utility"
echo "Usage: $0 {pre|post}"
# echo "Usage: $0 {pre|post|status}"
echo " pre : Collecting Pre Patch logs."
echo " post : Collecting Post Patch logs."
# echo " status : Current status of machine."
;;
esac
