#!/usr/bin/python
import RPi.GPIO as GPIO
import time

GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)

# init list with pin numbers

pinList = [4, 22, 6, 26]

# loop through pins and set mode default state is 'low'

for i in pinList:
    GPIO.setup(i, GPIO.OUT)



# active each relay for 2 seconds with 2 second delay between each activation
for i in pinList:
    GPIO.output(i, GPIO.HIGH)
    print i, " energised"
#    time.sleep(2)
    GPIO.output(i, GPIO.LOW)
    print i, " off"
    time.sleep(0.25)


# Reset GPIO settings
#GPIO.cleanup()
