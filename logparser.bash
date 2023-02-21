#!/bin/bash
# Barry Chen, Department of Computer Science, McGill ID: 260952566

# Check Usage
if [[ $# -ne 1 ]]
then
	echo "Wrong Usage: Usage ./logparser.bash <logdir>"
	exit 1
fi
# Check if the argument is a valid directory or not
if [[ ! -d $1 ]]
then
	echo "Error: $1 is not a valid directory name" >&2	
	exit 2
fi

directory=$1
for file in $(ls $1) # for each process, aka, for each broadcaster
do
	processid=$(echo $file | sed -n 's/'.'log//p' | sed -n 's/\./':'/p') #find the broadcasters' indentifier
	msgids=$(awk '/Broadcast message/ { print $NF }' < ${directory}/$file) #find the message id list for that broadcaster
	if [[ $msgids = $NOSUCH ]] # only find for broadcaster
	then
		continue
	fi
	for id in $msgids #for each message id in message id list
	do	
		#Go over the logfile to find the sendtime of that broadcaster by tracing its message id
		sendtime=$(awk -v number=$id '/Broadcast message/ {if ($NF == number) {print $4; exit}}' < ${directory}/$file)
		for log in $(ls $1) #for each process, aka, for each receiver
		do
			#Find the receivers' identifier and its receive and deliver time for that broadcaster with corresponding message id.
			rvpattern=${processid}:val:$id
			dvpattern=$(echo ":$id")
			rvmessage=$(echo "[senderProcess:$rvpattern]")
			receiveid=$(echo $log | sed -n 's/'.'log//p' | sed -n 's/\./':'/p')
			rdtime=$(awk -v m=$rvmessage -v p=$dvpattern -v proid=$processid '/Received a message from./ {if ($NF == m) {rvtime=$4}} 
			/deliver INFO:/ {if ($10 == p && $NF == proid) {dvtime=$4; exit}} END {OFS=","; print rvtime,dvtime}' < ${directory}/$log)
			#Concatenate all the required variable into a string and send it to the csv file.
			echo "$processid,$id,$receiveid,$sendtime,$rdtime" >> logdata.csv 
		done
	done
done

# Extract each receiver's indentifier from logdata.csv file to make the header of the stats.csv file
header=$(awk 'BEGIN { FS="," } {print $3","}' < logdata.csv | sort -u)
header=$(echo $header | sed 's/ //g' | sed 's/,$//')
echo "broadcaster,nummsgs,$header" > stats.csv

# for each row
for sender in $(awk 'BEGIN { FS="," } {print $1}' < logdata.csv | sort -u)
do

        percentages="" #empty the percentage for every row
	# fing the total number of message broadcasted for each broadcaster.
        nummsgs=$(awk -v broadcaster=$sender 'BEGIN {FS=",";total=0} {if ($1 == broadcaster && int($2) > total) {total=int($2)}} END {print total}' < logdata.csv)
        # for each column
       	for receiver in $(awk 'BEGIN { FS="," } {print $3}' < logdata.csv | sort -u)
        do

		#calculate the percentage, the counter is to record the number of message which does not delivered to the receiver.
                ptg=$(awk -v column=$receiver -v broadcaster=$sender -v total=$nummsgs 'BEGIN {FS=",";counter=0}
                {if ($1 == broadcaster && $3 == column && $NF == "" ) {counter++}} END {print ((total-counter)/total)*100 }' < logdata.csv)
                #Concatenate the percentage number of each receiver corresponded to that broadcaster
		percentages="$percentages,$ptg"
        
	done
	# output the information of each row to the stats.csv
        echo "$sender,$nummsgs$percentages" >> stats.csv
done

echo "<HTML>" > stats.html
echo "<BODY>" >> stats.html
echo "<H2>GC Efficiency</H2>" >> stats.html
echo "<TABLE>" >> stats.html
# first replacing the comma with html tag for the header, then replacing comma for each row. Always start on the beginning of the line to the end of line.
sed 's/^/,/' < stats.csv | sed 's/$/,/' | sed '1s/^,/<TR><TH>/' | sed '1s/,/<\/TH><TH>/g' | sed '1s/<\/TH><TH>$/<\/TH><\/TR>/' | sed 's/^,/<TR><TD>/' | sed 's/,/<\/TD><TD>/g' | sed 's/<\/TD><TD>$/<\/TD><\/TR>/' >> stats.html
echo "</TABLE>" >> stats.html
echo "</BODY>" >> stats.html
echo "</HTML>" >> stats.html

