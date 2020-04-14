# RaspberryPiPingRebooteriser
This script written for the Raspberry Pi resets a device when the internet connection is lost for a period of time.

It does the following:

- Every six seconds, it pings www.google.co.uk

- If that ping comes back within 10 seconds, the file
  /tmp/pingrebooter/failedpingcount.txt is set to 0

- If that ping doesn't come back within 10 seconds, the file
  /tmp/pingrebooter/failedpingcount.txt is read and its value incremented by
  1 before being written back to the file.

  So, if the last ping doesn't come back within 10 seconds, and
  /tmp/pingrebooter/failedpingcount.txt contains "4", then we update the file
  with the number 5.

- If /tmp/pingrebooter/failedpingcount.txt is greater than 10, we want to
  reboot - load /tmp/pingrebooter/lastreboottime.txt and parse the timestamp
  in the file.

- If the timestamp is greater than 15 minutes ago, reset
  /tmp/pingrebooter/failedpingcount.txt to 0, set
  /tmp/pingrebooter/lastreboottime.txt to now, turn off the relay for 20
  seconds, then turn it back on.

- If the last reboot timestamp is LESS than 15 minutes ago, we don't want to
  reboot yet (because it's likely the last reboot didn't fix the issue; it
  might not be a problem that can be fixed by a reboot), so just increment
  /tmp/pingrebooter/failedpingcount.txt by 1 and continue.
