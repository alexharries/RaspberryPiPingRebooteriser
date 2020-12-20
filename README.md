# RaspberryPiPingRebooteriser

This script written for the Raspberry Pi can be used to power-cycle mains-connected devices when the internet connection is lost for a period of time.

This requires the addition of a Raspberry Pi relay board, and you will need to wire the switched side of the relays to switch mains electricity; for example, I have wired mine to interrupt the supply to a standard UK four-way extension lead.

Also, because this script is written by someone with a terrible track record for writing awful shell scripts (hey, that's me!) you would be well-advised to run away from this code very quickly... 

## Obligatory scary electrical warning

Obviously, because this involves working with mains electricity, it is DANGEROUS and you must either ensure you are competent to take this work on, or enlist the help of an electrician.

Your primary considerations are:

* The mains-voltage and electronics-voltage (5V) sides of the relay circuitry are double-insulated from each other
* Mains conductors must be suitably insulated from each other
* Strain relief is necessary on the mains cables
* A suitable, impact-proof enclosure for your Raspberry Pi and relay board are needed
* You must take steps to ensure the relays aren't overloaded - e.g. with suitable signage and an appropriate fuse in your plug, if you use fused plugs where you are, and
* Your wiring meets the local standards or laws wherever you are.

## Yerbut, what does it do?

This script does the following:

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
