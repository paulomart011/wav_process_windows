#!/bin/bash
#
# Sript       : tkpostrecording.sh
# Description : Recordings post process and repository queues management
# 

logInfo() {
		if [ "$logEnabled" == 1 ]; then
			echo `date +%r-%N`  "INFO: $1" >> $logfile
		fi
}

logError() {
		echo `date +%r-%N` "ERROR: $1" >> $logfile
}

checkParams() {
	  
  logEnabled=1
	configfile=/etc/asterisk/inconcert.conf
	ftpuser='inconcert'
	ftppassword='inconcert'
	PositionAgent="right"
	
	# Get and trim blank spaces from asterisk inconcert.conf file:
	recordingdir=`cat $configfile | grep "recordingdir" | sed "s/recordingdir=//"`
	recordingdir=${recordingdir## }
	recordingdir=${recordingdir%% }
	recordingremotedir=`cat $configfile | grep "recordingremotedir" | sed "s/recordingremotedir=//"`
	recordingremotedir=${recordingremotedir## }
	recordingremotedir=${recordingremotedir%% }
	recordingqueues=`cat $configfile | grep "recordingqueues" | sed "s/recordingqueues=//"`
	recordingqueues=${recordingqueues## }
	recordingqueues=${recordingqueues%% }
	recordingremotehost=`cat $configfile | grep "recordingremotehost" | sed "s/recordingremotehost=//"`
	recordingremotehost=${recordingremotehost## }
	recordingremotehost=${recordingremotehost%% }
	recordStereo=`cat $configfile | grep "recordStereo" | sed "s/recordStereo=//"`
	recordStereo=${recordStereo## }
	recordStereo=${recordStereo%% }
	cmdCentos='nice -n 5 /usr/sbin/soxmix' 
	cmdDebian='nice -n 5 /usr/bin/sox' 
	if [ "${recordStereo}" == "1" ]; then
		cmdDebian="$cmdDebian -M"
	fi
	
	logfile=/tmp/tkpostrecording.log
	runningLocal=`cat $configfile | grep "localmixing" | sed "s/localmixing=//"`
	runningLocal=${runningLocal## }
	runningLocal=${runningLocal%% }
	OS="Centos"
	if [ -f /etc/debian_version ]; then
		OS="Debian"
	fi
	#
	# Previous checking
	#
	r=`echo $recordingqueues | grep "#"`
	if [ "$r" != "" ]; then
	   recordingqueues=""
	fi
	
	if [ "$recordingqueues" == "" ]; then
		logError "Error there is no recording queues configured, please review $configfile" 
	  exit 1
	fi
	
	r=`echo $recordingremotedir | grep "#"`
	if [ "$r" != "" ]; then
	   recordingremotedir=""
	fi
	
	if [ "$runningLocal" == 1 ]; then
		CmdUpload="cp "
		if [ "$recordingdir" == "$recordingremotedir" ]; then
			logError "Local mixing cannot use same source and destiny directory $recordingdir"
			exit 1
		fi
	else
		CmdUpload="ncftpput -V -t 10 -u $ftpuser -p $ftppassword $recordingremotehost "
		runningLocal=0		
		if [ "$recordingremotehost" == "" ]; then
			logError "Remote mixing cannot have empty recordingremotehost configuration variable"
			exit 1
		fi
	fi	

	if [ "$recordingremotedir" == "" ]; then
		logError "Error there is no remote path configured, please review $configfile" 
	  exit 1
	fi
	
	if [ "$7" != "" ]; then
		eval "$1='1'";
	elif [ "$4" != "" ]; then
		eval "$1='2'";
	else
		eval "$1='3'";
	fi
		
}

#ResolveQueueAndNumber(id, fullid, predefinedQueue)
function ResolveQueueAndNumber() {
	local callId=$1
	local fullPart=$2
	local preQueue=$3
	local number
	local foundFiles
	local numberReplaced
	
	# Just select a random queue (no matters if file goes to the same where there is another from same ID beeing processed or not => changed on server side multi-part safe parallel puts)
	if [ "$predefinedQueue" != "" ]; then
	    	queueName=$predefinedQueue
	    	logInfo "Using predefined queue $queueName as selection" 
	fi
	#busco archivos con mismo ID. Si lo encuentro copio a la misma cola.
	foundFiles=""
	for i in `seq 1 $recordingqueues`;
	do
		foundFiles=""
		if [ "$runningLocal" == 1 ]; then
			if [ "$OS" == "Debian" ]; then
				logInfo "ls $recordingremotedir/q$i | grep $callId"
				foundFiles=`ls $recordingremotedir/q$i | grep $callId`
			else
				logInfo "lsic $recordingremotedir/q$i | grep $callId"
				foundFiles=`lsic $recordingremotedir/q$i | grep $callId`
			fi
			
		else
			#Ftp file finding command
			logInfo "ncftpls -g -u $ftpuser -p $ftppassword -i "$recordingremotedir/q$i/*" ftp://$recordingremotehost | grep $callId"
			foundFiles=`ncftpls -g -u $ftpuser -p $ftppassword -i "$recordingremotedir/q$i/*" ftp://$recordingremotehost 2>>$logfile | grep $callId`
		fi
		if [ "$foundFiles" != "" ]; then
			queueName="q"$i
			logInfo "Found previous part on queue: $queueName"
			break
		fi
	done
	if [ "$queueName" == "" ]; then
		queueName=`perl -e "print('q' . int(rand($recordingqueues)+1));"` #genero un random entre 1 y numero de colas
		logInfo "Generated random queue $queueName as selection from a set of $recordingqueues queues" 
	fi
	
	partNumber=""
	
}

function checkFileExistence() {
		#tienen que estar in out y xml, sino fallo y salgo nomas...
		local in=$1
		local out=$2
		local xml=$3
		
		local isin=`ls $in`
		if [ "$isin" == "" ]; then
			logError "File $in wasn't found on disk" 
			exit 1
		fi
		local isin=`ls $out`
		if [ "$isin" == "" ]; then
			logError "File $out wasn't found on disk" 
			exit 1
		fi
		local isin=`ls $xml`
		if [ "$isin" == "" ]; then
			logError "File $xml wasn't found on disk" 
			exit 1
		fi
}

#UploadToMixerServer(in,out,destino, cola)
function UploadToMixerServer() {
	
  logInfo '########################################################################################'  
  logInfo "Start Execution"  
  localdate=`date`
  local in=$1
  local out=$2
  local predefinedQueue=$4
  local recordingdir="$recordingdir"
  
	    
  logInfo "UploadToMixerServer:  $1 $2 $3 $4"
	in_file=`perl -e "print(substr('$1',rindex('$1','/')+1));"`
	out_file=`perl -e "print(substr('$2',rindex('$2','/')+1));"`
	output_file=`perl -e "print(substr('$3',rindex('$3','/')+1));"` 
	callIdentification=`echo $output_file | sed "s/.mp3//"`
	
	#callidentificacion tiene el id con parte _numero
	callGuid=`perl -e "print(substr('$callIdentification',0,index('$callIdentification','_')));"`
	checkFileExistence $in $out $recordingdir/$callIdentification.xml
	mv $recordingdir/$callIdentification.xml $recordingdir/$callIdentification.xml.tmp
	xml_file=$callIdentification.xml.tmp
		 
	logInfo "Processing files for id:$callGuid, input:$in_file output:$out_file xml:$xml_file predefinedQueue:$predefinedQueue" 
	ResolveQueueAndNumber $callGuid $callIdentification $predefinedQueue
	if [ "$partNumber" != "" ]; then
		logInfo "Part number to use is $partNumber" 
		#tengo que mover los archivos viejos a nuevos para no pisar!
		mv $recordingdir/$in_file $recordingdir/$callGuid-in$partNumber.wav
		mv $recordingdir/$out_file $recordingdir/$callGuid-out$partNumber.wav
		mv $recordingdir/$xml_file $recordingdir/$callGuid$partNumber.xml.tmp
		sed "s/_[0-9]\?[0-9].mp3/$partNumber.mp3/" $recordingdir/$callGuid$partNumber.xml.tmp -i
		in_file=$callGuid-in$partNumber.wav
		out_file=$callGuid-out$partNumber.wav
		outout_file=$callGuid$partNumber.mp3
		xml_file=$callGuid$partNumber.xml.tmp
		callIdentification=$callGuid$partNumber
		logInfo "Changed partnumber files for id:$callGuid, input:$in_file output:$out_file xml:$xml_file" 
	fi
	buildPrsFile $callIdentification
	
	local remotePath=$recordingremotedir/$queueName
	
	#Upload files        
	local uploaded=0;
	if [ "$runningLocal" == 1 ]; then
		logInfo "local command: $CmdUpload $recordingdir/$in_file $recordingdir/$out_file $recordingdir/$xml_file $recordingdir/$callIdentification.prs $remotePath" 
		eval $CmdUpload $recordingdir/$in_file $recordingdir/$out_file $recordingdir/$xml_file $recordingdir/$callIdentification.prs $remotePath
		uploaded=$?
	else
		logInfo "Ftp command: $CmdUpload $remotePath $recordingdir/$in_file $recordingdir/$out_file $recordingdir/$xml_file $recordingdir/$callIdentification.prs" 
		eval $CmdUpload $remotePath $recordingdir/$in_file $recordingdir/$out_file $recordingdir/$xml_file $recordingdir/$callIdentification.prs >> $logfile 2>&1
		uploaded=$?
	fi
	if [ "$uploaded" == 0 ]; then
			logInfo "Files uploded ok to ftp server for id:$callIdentification" 
			rm -f $recordingdir/$in_file
			rm -f $recordingdir/$out_file
			rm -f $recordingdir/$xml_file
			rm -f $recordingdir/$callIdentification.prs
	else
		logError "Error transfering files for $callIdentification to ftp server" 
		rm -f $recordingdir/$callIdentification.prs
		mv $recordingdir/$callIdentification.xml.tmp $recordingdir/$callIdentification.xml
		logInfo "Cleanup complete for id $callIdentification"
		exit 1
	fi
   
}


MixLocally() {
	
	local leftFile=$1
	local rightFile=$2
	local outFile=$3 	
	
	logInfo "Mixing locally on $OS S.O.. left:$leftFile right:$rightFile out:$outFile" 
	if [ "$OS" == "Debian" ]; then
		$cmdDebian -G -m $leftFile $rightFile -c 1 -r 11025 $outFile
	else
		$cmdCentos $leftFile $rightFile -w -c 1 -r 11025 $outFile
	fi
}

main() {
	
	local recordingCase
	
	#los parametros de ejecucion tienen que persistir tal cual entraron...
	execparams=`echo $1 $2 $3 $4 $5 $6 $7`
	checkParams recordingCase $1 $2 $3 $4 $5 $6 $7 
	case $recordingCase in
		'1')
				UploadToMixerServer $1 $2 $6 $7
				;;
		'2')
				MixLocally $1 $2 $3
				;;
		'3')
				logError "Incorrect number of parameters" 
				;;
	esac
	
	exit 1;
}

buildPrsFile() {
	local callId=$1
	local in=$recordingremotedir/$in_file
	local out=$recordingremotedir/$out_file
	
	logInfo "Building prs file $recordingdir/$callId.prs for id $callId" 
	
	#Validacion WAV
	grabarWAV=0
    mustWAV=$(echo $in_file | awk -F "_" {'print $2'})
    logInfo "Valor de mustWAV:  $mustWAV" 
    # Verificar si el segundo campo esta modificado
    if [[ "$mustWAV" =~ ^[0-9]+$ ]]; then
        if [ "$mustWAV" -ge 900 ]; then
            logInfo "El segundo campo es mayor o igual a 900 Se mixea en WAV"
			grabarWAV=1
        else
            logInfo "No se mixea en WAV" 
        fi
    fi

	#armado del PRS           
	if [ "$OS" == "Debian" ]; then	
		if [ "${recordStereo}" != "1" ]; then
			#Grabo en mono que consumo menos espacio en disco.
			echo "$cmdDebian -G -m $recordingremotedir/$queueName/$in_file $recordingremotedir/$queueName/$out_file -c 1 -r 11025 $recordingremotedir/$queueName/$callId.mp3 &&" > $recordingdir/$callId.prs
			
			#Validacion WAV
			if [ "$grabarWAV" -eq 1 ]; then
				logInfo "Mixeando en WAV"
				echo "$cmdDebian -M $recordingremotedir/$queueName/$out_file $recordingremotedir/$queueName/$in_file /GrabacionesWAV/$queueName/$callId.wav && " >> $recordingdir/$callId.prs	
			fi
		
		else
			#Grabo en Stereo y ademas ordeno los canales.
			local direction=`grep -o '<direction>' $recordingdir/$callId.xml.tmp `
			local trnfCrossNode=`grep -o '<TrnfCrossNode>' $recordingdir/$callId.xml.tmp`
			local braces=`echo $callId|awk '{print match($0,"{")}'`
			logInfo "direction: $direction, trnfCrossNode: $trnfCrossNode, braces: $braces"	
			if [ "$PositionAgent" == "left" ]; then
				echo "$cmdDebian $recordingremotedir/$queueName/$in_file $recordingremotedir/$queueName/$out_file $recordingremotedir/$queueName/$callId.mp3 && " >> $recordingdir/$callId.prs
			
				#Validacion WAV
				if [ "$grabarWAV" -eq 1 ]; then
					logInfo "Mixeando en WAV"	
					echo "$cmdDebian -M $recordingremotedir/$queueName/$in_file $recordingremotedir/$queueName/$out_file /GrabacionesWAV/$queueName/$callId.wav && " >> $recordingdir/$callId.prs	
				fi
				
				
			else
				echo "$cmdDebian $recordingremotedir/$queueName/$out_file $recordingremotedir/$queueName/$in_file $recordingremotedir/$queueName/$callId.mp3 && " >> $recordingdir/$callId.prs
			
				#Validacion WAV
				if [ "$grabarWAV" -eq 1 ]; then
					logInfo "Mixeando en WAV"
					echo "$cmdDebian -M $recordingremotedir/$queueName/$out_file $recordingremotedir/$queueName/$in_file /GrabacionesWAV/$queueName/$callId.wav && " >> $recordingdir/$callId.prs	
				fi
			
			fi
		fi
	else
		echo "$cmdCentos $recordingremotedir/$queueName/$in_file $recordingremotedir/$queueName/$out_file -w -c 1 -r 11025 $recordingremotedir/$queueName/$callId.mp3 &&" > $recordingdir/$callId.prs
	fi
	echo "rm -f $recordingremotedir/$queueName/$in_file &&" >> $recordingdir/$callId.prs  
	echo "rm -f $recordingremotedir/$queueName/$out_file &&" >> $recordingdir/$callId.prs
	echo "mv $recordingremotedir/$queueName/$callId.xml.tmp $recordingremotedir/$queueName/$callId.xml" >> $recordingdir/$callId.prs
}

	
main $1 $2 $3 $4 $5 $6 $7
