#!/bin/bash
# PingRebooter
#
# This script written for the Raspberry Pi resets a device when the internet
# connection is lost for a period of time.
#
# You must run this script as sudo.
#
# It does the following:
#
# - Every six seconds, it pings www.google.co.uk
#
# - If that ping comes back within 10 seconds, the file
#   /tmp/pingrebooter/failedpingcount.txt is set to 0
#
# - If that ping doesn't come back within 10 seconds, the file
#   /tmp/pingrebooter/failedpingcount.txt is read and its value incremented by
#   1 before being written back to the file.
#
#   So, if the last ping doesn't come back within 10 seconds, and
#   /tmp/pingrebooter/failedpingcount.txt contains "4", then we update the file
#   with the number 5.
#
# - If /tmp/pingrebooter/failedpingcount.txt is greater than 10, we want to
#   reboot - load /tmp/pingrebooter/lastreboottime.txt and parse the timestamp
#   in the file.
#
# - If the timestamp is greater than 15 minutes ago, reset
#   /tmp/pingrebooter/failedpingcount.txt to 0, set
#   /tmp/pingrebooter/lastreboottime.txt to now, turn off the relay for X
#   seconds, then turn it back on.
#
# - If the last reboot timestamp is LESS than 15 minutes ago, we don't want to
#   reboot yet (because it's likely the last reboot didn't fix the issue; it
#   might not be a problem that can be fixed by a reboot), so just increment
#   /tmp/pingrebooter/failedpingcount.txt by 1 and continue.

#
# Check if we're sudo; if not, no bueno, no go.
#
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root."
  exit
fi

#
# Set up our variabibbles.
#

# Temporary directory.
TEMPDIR="/tmp/pingrebooter"

# The file which contains the count of how many failed tests we've had in a row.
FAILEDPINGCOUNTFILENAME="failedpingcount.txt"

# The file which disables rebooting - touch this file to prevent pingrebooter
# rebooting devices e.g. when diagnosing a problem.
PINGREBOOTERDISABLEFILENAME="pingrebooterdisable.txt"

# The file which contains the timestamp of the last reboot time.
LASTREBOOTTIMEFILENAME="lastreboottime.txt"

# The logs directory.
LOGSDIRECTORY="/var/log/pingrebooter/"

# The log file name.
LOGFILENAME="log.txt"

# A reliable domain which we will ping.
# We want to use a domain name here because it will help us spot
# DNS failures, but this seems to be unreliable right now.
DOMAINTOPING="www.google.co.uk"
#DOMAINTOPING="8.8.8.8"

# How frequently should we send pings.
PINGINTERVALSECONDS=6

# How long should we wait before we assume a ping is considered "dead".
PINGMAXIMUMSECONDS="$PINGINTERVALSECONDS"

# 10 ping failues before reboot.
PINGFAILURECOUNTBEFOREREBOOT=10

# Don't reboot within 900 seconds (15 minutes) of last reboot.
PINGDONOTREBOOTWITHINSECONDS=900

# Turn the power off to the router for X seconds.
POWEROFFSECONDS=10

# Wait how many seconds for the router to reboot.
ROUTERREBOOTSECONDS=180

# Set the GPIO pin number which is connected to the relay.
# @see https://medium.com/coinmonks/controlling-raspberry-pi-gpio-pins-from-bash-scripts-traffic-lights-7ea0057c6a90
GPIOPIN=9

# Get the path to the script.
SCRIPT=`realpath $0`
SCRIPTPATH=`dirname "$SCRIPT"`

python "$SCRIPTPATH/power_on.py"

#
# Functions.
#

# Get the current Unix timestamp.
getcurrenttimestamp() {
  TIMESTAMP=`date "+%s"`
}

# Get the current date-time.
getcurrentdatetime() {
  DATETIME=`date +"%Y-%m-%d %H:%M:%S"`
}

# Create the last rebooted file.
createfailedpingcountfile() {
  echo "$1" > "$TEMPDIR/$FAILEDPINGCOUNTFILENAME"
}

# Create the last rebooted file.
createlastrebootedfile() {
  # Set last reboot time to the interval seconds ago so we can reboot
  # immediately if needed.
  echo "$1" > "$TEMPDIR/$LASTREBOOTTIMEFILENAME"
}

# Create the log file.
createlogfile() {
  mkdir -p /var/log/pingrebooter/
  touch /var/log/pingrebooter/log.txt
  getcurrentdatetime
  echo "$DATETIME Startup." >> "${LOGSDIRECTORY}${LOGFILENAME}"
}

#
# Initialise.
#

createlogfile

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
  createlastrebootedfile 0
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
  # Get date-time.
  getcurrentdatetime

  echo "
$DATETIME: ping -c 1 $DOMAINTOPING -W $PINGMAXIMUMSECONDS -v:"

  if ping -c 1 "$DOMAINTOPING" -W $PINGMAXIMUMSECONDS -v &> /dev/null
  then
    echo "OK"

    # Reset /tmp/pingrebooter/failedpingcount.txt to 0.
    echo "0" > "$TEMPDIR/$FAILEDPINGCOUNTFILENAME"

  else
    # Read /tmp/pingrebooter/failedpingcount.txt.
    FAILEDPINGCOUNT=`cat "$TEMPDIR/$FAILEDPINGCOUNTFILENAME"`

    FAILEDPINGCOUNT=$((FAILEDPINGCOUNT + 1))

    echo "\
********************************
********************************
********************************
Not ok: Failed ping count: $FAILEDPINGCOUNT
********************************
********************************
********************************"

    createfailedpingcountfile "$FAILEDPINGCOUNT"

    getcurrentdatetime
    echo "$DATETIME ping $DOMAINTOPING timeout - $FAILEDPINGCOUNT of $PINGFAILURECOUNTBEFOREREBOOT before reboot" >> "${LOGSDIRECTORY}${LOGFILENAME}"

    # If failed ping count > number of failed pings before reboot, and last
    # reboot was more than PINGDONOTREBOOTWITHINSECONDS ago, reboot the router.
    if [[ "$FAILEDPINGCOUNT" -ge "$PINGFAILURECOUNTBEFOREREBOOT" ]]; then
      # Read in $TEMPDIR/$LASTREBOOTTIMEFILENAME and subtract now timestamp from
      # the timestamp in that file.
      LASTREBOOTTIME=`cat "$TEMPDIR/$LASTREBOOTTIMEFILENAME"`

      getcurrenttimestamp

      # Declare our timestamps as integers so we do mathumaticks.
      LASTREBOOTSECONDSAGO=0

      declare -i TIMESTAMP
      declare -i LASTREBOOTTIME
      declare -i LASTREBOOTSECONDSAGO

      LASTREBOOTSECONDSAGO="$TIMESTAMP-$LASTREBOOTTIME"

      echo "$DATETIME Last reboot timestamp: $LASTREBOOTTIME = $LASTREBOOTSECONDSAGO seconds ago" >> "${LOGSDIRECTORY}${LOGFILENAME}"
      echo "$DATETIME LASTREBOOTTIME $LASTREBOOTTIME - PINGDONOTREBOOTWITHINSECONDS: $PINGDONOTREBOOTWITHINSECONDS" >> "${LOGSDIRECTORY}${LOGFILENAME}"

      if [[ "$LASTREBOOTSECONDSAGO" -ge "$PINGDONOTREBOOTWITHINSECONDS" ]]; then
        echo "Last reboot was more than $PINGDONOTREBOOTWITHINSECONDS seconds ago; rebooting router (if $TEMPDIR/$PINGREBOOTERDISABLEFILENAME doesn't exist) ..."

        getcurrentdatetime

        echo "$DATETIME Rebooting : last reboot at least $PINGDONOTREBOOTWITHINSECONDS seconds ago (touch $TEMPDIR/$PINGREBOOTERDISABLEFILENAME if you wish to disable rebooting)..." >> "${LOGSDIRECTORY}${LOGFILENAME}"

        # Reset failed ping counter to 0.
        createfailedpingcountfile 0

        # Set last reboot timestamp to now.
        createlastrebootedfile "$DATETIME"

        # Beep once.
        tput bel

        # Do reboot. Turn relay off on pin $GPIOPIN.
        echo "Router off..."

        getcurrentdatetime
        echo "$DATETIME Router off..." >> "${LOGSDIRECTORY}${LOGFILENAME}"

        if [[ -f "$TEMPDIR/$PINGREBOOTERDISABLEFILENAME" ]]; then
          echo "$DATETIME Not rebooting because $TEMPDIR/$PINGREBOOTERDISABLEFILENAME exists - please delete this file to enable rebooting." >> "${LOGSDIRECTORY}${LOGFILENAME}"
        else
          python "$SCRIPTPATH/power_off.py"
        fi

        echo "Waiting $POWEROFFSECONDS..."

        getcurrentdatetime
        echo "$DATETIME Waiting $POWEROFFSECONDS..." >> "${LOGSDIRECTORY}${LOGFILENAME}"

        sleep $((POWEROFFSECONDS - 1))

        # Beep twice.
        tput bel
        sleep 1
        tput bel

        # Turn back on...
        echo "Router on..."

        getcurrentdatetime
        echo "$DATETIME Router on..." >> "${LOGSDIRECTORY}${LOGFILENAME}"

        if [[ -f "$TEMPDIR/$PINGREBOOTERDISABLEFILENAME" ]]; then
          echo "$DATETIME Not rebooting because $TEMPDIR/$PINGREBOOTERDISABLEFILENAME exists - please delete this file to enable rebooting." >> "${LOGSDIRECTORY}${LOGFILENAME}"
        else
          python "$SCRIPTPATH/power_on.py"
        fi

        # Sleep for 60 seconds while the router restarts...
        echo "Waiting $ROUTERREBOOTSECONDS seconds while router reboots..."

        getcurrentdatetime
        echo "$DATETIME Waiting $ROUTERREBOOTSECONDS seconds while router reboots..." >> "${LOGSDIRECTORY}${LOGFILENAME}"

        sleep "$ROUTERREBOOTSECONDS"
      fi
    fi
  fi

  sleep "$PINGINTERVALSECONDS"
done
