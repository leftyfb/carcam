#!/bin/bash

logfile=/media/pics/log-$(date +"%s").log
exec > $logfile 2>&1

timeset=0
getgpstime () {
    while [ $timeset = 0 ] ; do
        echo "timeset = $timeset"
        sudo python /bin/gpstime.py
        gottime=$?
        echo $gottime
        if [ $gottime = 1 ] ; then
            echo "not set yet"
            return 0
        fi
        echo "DONE"
    timeset=1
    done
    return 1
}

echo "$(date "+%b %d %H:%M:%S") Setting time from GPS..."
getgpstime
echo "$(date "+%b %d %H:%M:%S") Done. The time has been set to $(date)" 

## turn on blue light to indicate all is well ###
    /etc/init.d/blinkblue stop
    echo "18" > /sys/class/gpio/export
    echo "out" > /sys/class/gpio/gpio18/direction
    echo "1" > /sys/class/gpio/gpio18/value
    echo "18" > /sys/class/gpio/unexport
echo "$(date "+%b %d %H:%M:%S") Turned on Blue light"

workingdir=/media/pics/$(date +"%s")
echo "workingdir = $workingdir"
takepics=1
lockfile=/var/run/takepics.lock

mkdir -p $workingdir/pics

echo "1" > /var/run/takepics.lock
gpslock=0


pollgps() {
	  gpslock=1
	  echo "polling gps......"
	  gpscoords=$(python /bin/getgps.py)
	  echo "$timestamp $gpscoords" >> $workingdir/gps.log &
	  gpslock=0 
	  prevgpscoords=$gpscoords 
	  echo "DONE polling gps......"
}


while [ "$takepics" =  "1" ];
	do
	 timestamp=$(date +"%s")
         if [ "$gpslock" = 0 ] ; then	 
	  pollgps &
	 else
	  gpscoords=$prevgpscoords
	  echo "$timestamp $gpscoords" >> $workingdir/gps.log
	 fi
	 #fswebcam --no-banner -r 640x360 -d /dev/video0 $workingdir/pics/$timestamp.jpg &
	 echo "taking picture $workingdir/$timestamp.jpg"
	 raspistill -w 640 -h 360 -vf -t 0 -o $workingdir/pics/$timestamp.jpg &
	 now=$(date)
	 filecount=$(ls $workingdir/pics/|wc -l)
	 spacefree=$(df -m $workingdir|tail -n1|awk '{print $4}')
	 sleep 3
	 displaycoords=$(grep $timestamp $workingdir/gps.log|awk '{print $2,$3}')
	 echo "uploading $workingdir/$timestamp to webserver"
	 convert $workingdir/pics/$timestamp.jpg -fill white -undercolor '#00000080' -pointsize 20 -gravity SouthWest -annotate +0+5 " $now" -gravity SouthEast -annotate +0+5 " Photos: $filecount   Free Space: $spacefree MB " -gravity NorthWest -annotate +0+5 " Location: $displaycoords" /var/www/pic.jpg
	 takepics=$(cat $lockfile)
done
rm $lockfile
