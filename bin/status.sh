#!/bin/bash

#sleep 10
echo "25" > /sys/class/gpio/unexport
echo "25" > /sys/class/gpio/export
echo "in" > /sys/class/gpio/gpio25/direction
switch=$(cat /sys/class/gpio/gpio25/value)

halting=0
while [ "$switch" = "1" ] && [ "$halting" = "0" ]
 do

### check for button press
  switch=$(cat /sys/class/gpio/gpio25/value)
  if [ "$switch" = "0" ] ; then
	halting=1
# turn blue off
    echo "18" > /sys/class/gpio/export
    echo "out" > /sys/class/gpio/gpio18/direction
    echo "0" > /sys/class/gpio/gpio18/value
# blink red
   # /etc/init.d/blinkblue stop
    /etc/init.d/blinkred start
   shutdown -h now
  fi

sleep 1
done
