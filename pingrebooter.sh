#!/bin/bash
# PingRebooter
#
# This script written for the Raspberry Pi resets a device when the internet
# connection is lost for a period of time.
#
# It does the following:
#
# - Every six seconds, it pings www.google.co.uk
#
# - If that ping comes back within 30 seconds, the file
#   /tmp/pingrebooter/failedpingcount.txt is set to 0
#
# - If that ping doesn't come back within 30 seconds, the file
#   /tmp/pingrebooter/failedpingcount.txt is read and its value incremented by
#   1 before being written back to the file.
#
#   So, if the last ping doesn't come back within 30 seconds, and
#   /tmp/pingrebooter/failedpingcount.txt contains "4", then we update the file
#   with the number 5.
#
# - If /tmp/pingrebooter/failedpingcount.txt is greater than 10, we want to
#   reboot - load /tmp/pingrebooter/lastreboottime.txt and parse the timestamp
#   in the file.
#
# - If the timestamp is greater than 10 minutes ago, reset
#   /tmp/pingrebooter/failedpingcount.txt to 0, set
#   /tmp/pingrebooter/lastreboottime.txt to now, turn off the relay for 20
#   seconds, then turn it back on.
#
# - If the last reboot timestamp is LESS than 10 minutes ago, we don't want to
#   reboot yet (because it's likely the last reboot didn't fix the issue; it
#   might not be a problem that can be fixed by a reboot), so just increment
#   /tmp/pingrebooter/failedpingcount.txt by 1 and continue.

#
# Set up our variabibbles.
#

# Temporary directory.
TEMPDIR="/tmp/pingrebooter"

# The file which contains the count of how many failed tests we've had in a row.
FAILEDPINGCOUNTFILENAME="failedpingcount.txt"

# The file which contains the timestamp of the last reboot time.
LASTREBOOTTIMEFILENAME="lastreboottime.txt"

# A reliable domain which we will ping.
DOMAINTOPING="www.google.co.uk"

# How frequently should we send pings.
PINGINTERVALSECONDS=6

# How long should we wait before we assume a ping is considered "dead".
PINGMAXIMUMSECONDS=10

# 10 ping failues before reboot.
PINGFAILURECOUNTBEFOREREBOOT=10

# Don't reboot within 900 seconds (15 minutes) of last reboot.
PINGDONOTREBOOTWITHINSECONDS=900

#
# Functions.
#

# Get the current Unix timestamp.
getcurrenttimestamp() {
  TIMESTAMP=`date "+%s"`
}

# Create the last rebooted file.
createfailedpingcountfile() {
  echo "$1" > "$TEMPDIR/$FAILEDPINGCOUNTFILENAME"
}

# Create the last rebooted file.
createlastrebootedfile() {
  getcurrenttimestamp
  echo "$TIMESTAMP" > "$TEMPDIR/$LASTREBOOTTIMEFILENAME"
}

#
# Initialise.
#

# Touch the files this script uses and confirm they exist; if they
# don't, exit with an error.
mkdir -p "$TEMPDIR" || { echo "PingRebooter could not create temporary directory $TEMPDIR; exiting."; exit 1; }

if [[ ! -f "$TEMPDIR/$FAILEDPINGCOUNTFILENAME" ]]; then
  createfailedpingcountfile 0
fi

if [[ ! -f "$TEMPDIR/$FAILEDPINGCOUNTFILENAME" ]]; then
  echo "PingRebooter could not create temporary file $TEMPDIR/$FAILEDPINGCOUNTFILENAME; exiting."
  exit 1
fi

if [[ ! -f "$TEMPDIR/$LASTREBOOTTIMEFILENAME" ]]; then
  createlastrebootedfile
fi

if [[ ! -f "$TEMPDIR/$LASTREBOOTTIMEFILENAME" ]]; then
  echo "PingRebooter could not create temporary file $TEMPDIR/$LASTREBOOTTIMEFILENAME; exiting."
  exit 1
fi

#
# Run.
#

while true
do
  echo "ping -c 1 $DOMAINTOPING -t $PINGMAXIMUMSECONDS -v:"

  if ping -c 1 "$DOMAINTOPING" -t 10 -v &> /dev/null
  then
    echo "OK"

    # Reset /tmp/pingrebooter/failedpingcount.txt to 0.
    echo "0" > "$TEMPDIR/$FAILEDPINGCOUNTFILENAME"

  else
    echo "Not ok"

    # Read /tmp/pingrebooter/failedpingcount.txt.
    FAILEDPINGCOUNT=`cat "$TEMPDIR/$FAILEDPINGCOUNTFILENAME"`
    echo "FAILEDPINGCOUNT: $FAILEDPINGCOUNT"

    FAILEDPINGCOUNT=$((FAILEDPINGCOUNT + 1))
    echo "FAILEDPINGCOUNT: $FAILEDPINGCOUNT"

    createfailedpingcountfile "$FAILEDPINGCOUNT"

    # If failed ping count > number of failed pings before reboot, and last
    # reboot was more than PINGDONOTREBOOTWITHINSECONDS ago, reboot the router.
    if (( "$FAILEDPINGCOUNT" > "$PINGFAILURECOUNTBEFOREREBOOT" )); then
      echo "FAILEDPINGCOUNT ($FAILEDPINGCOUNT) > PINGFAILURECOUNTBEFOREREBOOT ($PINGFAILURECOUNTBEFOREREBOOT)"

      # Read in $TEMPDIR/$LASTREBOOTTIMEFILENAME and subtract now timestamp from
      # the timestamp in that file.
      LASTREBOOTTIME=`cat "$TEMPDIR/$LASTREBOOTTIMEFILENAME"`

      echo "LASTREBOOTTIME: $LASTREBOOTTIME"

      getcurrenttimestamp
      LASTREBOOTSECONDSAGO=$((TIMESTAMP-LASTREBOOTTIME))

      echo "LASTREBOOTSECONDSAGO: $LASTREBOOTSECONDSAGO"

      if (( "$LASTREBOOTSECONDSAGO" > "$PINGDONOTREBOOTWITHINSECONDS" )); then
        echo "Rebooting router..."

        # Reset failed ping counter to 0.
        createfailedpingcountfile 0

        # Set last reboot timestamp to now.
        createlastrebootedfile

        # Do reboot.
        ./pingrebooter-doreboot.sh
      fi
    fi
  fi

  sleep "$PINGINTERVALSECONDS"
done
