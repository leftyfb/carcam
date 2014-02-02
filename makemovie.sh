#!/bin/bash

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

if [ -z $1 ] ; then
	echo "Usage: $0 <directory of pics>"
	exit 0
fi

workingdir=$1
logfile=$workingdir/gps.log
apikey=PUT_GOOGLE_MAPS_API_KEY_HERE
mkdir $workingdir/{maps,merged}

makemap() {
 width=150
 height=150
# zoom=10
 scale=1
# pathrange=40

linesbefore=$(grep -B200 "$1" $logfile|wc -l)
linesafter=$(grep -A200 "$1" $logfile|wc -l)
if [ "$linesbefore" -le "123" ] || [ "$linesafter" -le "123" ]; then
 distance="0"
else
 points1=$(grep -B21 "$1" $logfile |head -n1|awk '{print $2,$3}'|sed 's/,//g')
 points2=$(grep -A21 "$1" $logfile |tail -n1|awk '{print $2,$3}'|sed 's/,//g')
 lat1=$(echo $points1|awk '{print $1}')
 long1=$(echo $points1|awk '{print $2}')
 lat2=$(echo $points2|awk '{print $1}')
 long2=$(echo $points2|awk '{print $2}')
 distance=$(echo -e "scale=2;sqrt(($lat1 - $long1)^2 - ($lat2 - $long2)^2)" |bc|xargs printf "%1.0f\n")
fi

if [ "$distance" = "0" ]; then
	zoom=18
	prmultiplier=1
	pathrange=20
elif [ "$distance" = "1" ];then
	zoom=16
	prmultiplier=1
	pathrange=20
elif [ "$distance" = "2" ];then
	zoom=12
	prmultiplier=2
	pathrange=40
elif [ "$distance" = "3" ];then
	zoom=10
	prmultiplier=4
	pathrange=80
elif [ "$distance" = "4" ];then
	zoom=8
	prmultiplier=10
	pathrange=200
fi

 multipaths=$(echo -n "path=color:0x0000ff|weight:5"; \
 for i in `seq $pathrange -$prmultiplier 1`;do echo -n "|$(grep -B$i "$lat $long" $logfile|head -n1|awk '{print $2","$3}')";done; \
 echo -n "|$lat,$long"; \
  for i in `seq 1 +$prmultiplier $pathrange`;do echo -n "|$(grep -A$i "$lat $long" $logfile|tail -n1|awk '{print $2","$3}')";done)
 echo
 echo "$lat,$long"
 echo
wget "http://maps.googleapis.com/maps/api/staticmap?&$multipaths&sensor=false&size=${width}x${height}&zoom=$zoom&scale=$scale&center=$lat,$long&markers=size:mid%7C$lat,$long&format=png&key=$apikey" -O $workingdir/maps/$filename-map.png
 cp $workingdir/maps/$filename-map.png $workingdir/maps/tmp-map.png
 if [ $? -ne 0 ]; then
     echo "An error occured" >&2
     break 
 fi
	sleep 5
}


for i in `cat $logfile`
 do
	filename=$(echo $i|awk '{print $1}')
	lat=$(echo $i|awk '{print $2}')
	long=$(echo $i|awk '{print $3}')
	if [ -f $workingdir/pics/$filename.jpg ] ; then
		if [ -z $lat ] ; then
			lat=$prevlat
			long=$prevlong
		fi
		
		counter=0
		if [ $(( $counter % 5 )) -eq 0 ] ; then
#	    	 makemap $filename
		 echo
		else
		 echo
		 echo "Using previous google maps image"
		 echo
		 cp $workingdir/maps/tmp-map.png $workingdir/maps/$filename-map.png
   		fi
                let counter=counter+1
		if [ -f $workingdir/maps/$filename-map.png ] ; then
			echo "Merging $workingdir/pics/$filename.png and $workingdir/maps/$filename-map.png"
			####convert $workingdir/pics/$filename.jpg \( $workingdir/maps/$filename-map.png \) -gravity SouthWest -composite $workingdir/merged/$filename-merged.jpg
			convert $workingdir/pics/$filename.jpg \( $workingdir/maps/$filename-map.png  \) -strip -alpha on -compose dissolve -define compose:args='90' -gravity SouthWest -composite $workingdir/merged/$filename-merged.jpg
		else
			echo "No map file, using $workingdir/pics/$filename.png"
			cp $workingdir/pics/$filename.jpg $workingdir/merged/$filename-merged.jpg
		fi
		convert $workingdir/merged/$filename-merged.jpg -fill white -undercolor '#00000080' -pointsize 20 -gravity NorthWest -annotate +0+5 " $(date -d @$filename +"%Y/%m/%d %H:%M:%S") " $workingdir/merged/$filename-merged.jpg
		echo
	prevlat=$lat
	prevlng=$long
	fi
	echo $i >> /home/leftyfb/carcam.log
done
	

videooutput=$1.mp4
cat $workingdir/merged/*.jpg | avconv -f image2pipe -vcodec mjpeg -i - -vcodec libx264 -b 65536k /carcam/$videooutput

IFS=$SAVEIFS
