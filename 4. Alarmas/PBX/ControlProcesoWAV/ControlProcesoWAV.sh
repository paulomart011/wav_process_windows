#!/bin/bash
# Variables Iniciales
# Script: ControlProcessWAV
# Description: It runs every 1 minutes, and stop the process of WAV generation, copying an old version of tkpostrecording.sh


# Variables Iniciales
maxNumberOfAudios=2000
directoryBase1="/GrabacionesWAV"
directoryBase2="/GrabacionesWAVFailed"
pasteDirectory="/ControlProcesoWAV/tkpostrecordingOff.sh"
finalDirectory="/usr/sbin/tkpostrecording.sh"
archivoControl="/ControlProcesoWAV/archivo_control.txt"
logFile="/tmp/LogControlProcessWAV.log"
host_name=$(hostname)
ip_address=$(hostname -I | awk '{print $1}')
# separar destinatarios por comas
destinatarios="paulo.martinez@inconcertcc.com,ycastro@inconcertcc.com"
mensaje="Subject: Fallo Proceso WAV\n\nEl proceso de generacion de audios en WAV se detuvo debido a una falla que causo acumulacion de archivos.\n\nHost: $host_name\nIP: $ip_address"
LogEnabled=0
echo $logFile

logInfo() {
	if [ "$LogEnabled" == 1 ]; then
		echo `date +%r-%N`  "INFO: $1" >> $logFile
	fi
}

logError() {
		echo `date +%r-%N` "ERROR: $1" >> $logFile
}

main(){	

	logInfo "Comienzo de busqueda"
    
    	if [ -f "$archivoControl" ]; then
        	contenido=$(cat "$archivoControl")
		logInfo "Contenido $contenido"
        	if [ "$contenido" == "EJECUTAR" ]; then
			logInfo "entro al if"

			num_archivos_carpeta_1=$(find "$directoryBase1/q1/" -maxdepth 1 -type f | wc -l)
			num_archivos_carpeta_2=$(find "$directoryBase1/q2/" -maxdepth 1 -type f | wc -l)
			num_archivos_carpeta_3=$(find "$directoryBase1/q3/" -maxdepth 1 -type f | wc -l)
			num_archivos_carpeta_4=$(find "$directoryBase1/q4/" -maxdepth 1 -type f | wc -l)
			num_archivos_carpeta_5=$(find "$directoryBase1/q5/" -maxdepth 1 -type f | wc -l)
			num_archivos_carpeta_6=$(find "$directoryBase1/qp/" -maxdepth 1 -type f | wc -l)

			num_archivos_carpeta_7=$(find "$directoryBase2/q1/" -maxdepth 1 -type f | wc -l)
			num_archivos_carpeta_8=$(find "$directoryBase2/q2/" -maxdepth 1 -type f | wc -l)
			num_archivos_carpeta_9=$(find "$directoryBase2/q3/" -maxdepth 1 -type f | wc -l)
			num_archivos_carpeta_10=$(find "$directoryBase2/q4/" -maxdepth 1 -type f | wc -l)
			num_archivos_carpeta_11=$(find "$directoryBase2/q5/" -maxdepth 1 -type f | wc -l)
			num_archivos_carpeta_12=$(find "$directoryBase2/qp/" -maxdepth 1 -type f | wc -l)

			logInfo "$directoryBase1/q1/"
			logInfo "$num_archivos_carpeta_1"
			logInfo "$num_archivos_carpeta_2"

            		if [ $num_archivos_carpeta_1 -gt $maxNumberOfAudios ] || [ $num_archivos_carpeta_2 -gt $maxNumberOfAudios ] || [ $num_archivos_carpeta_3 -gt $maxNumberOfAudios ] || [ $num_archivos_carpeta_4 -gt $maxNumberOfAudios ] || [ $num_archivos_carpeta_5 -gt $maxNumberOfAudios ] || [ $num_archivos_carpeta_6 -gt $maxNumberOfAudios ] || [ $num_archivos_carpeta_7 -gt $maxNumberOfAudios ] || [ $num_archivos_carpeta_8 -gt $maxNumberOfAudios ] || [ $num_archivos_carpeta_9 -gt $maxNumberOfAudios ] || [ $num_archivos_carpeta_10 -gt $maxNumberOfAudios ] || [ $num_archivos_carpeta_11 -gt $maxNumberOfAudios ] || [ $num_archivos_carpeta_12 -gt $maxNumberOfAudios ]; then
        			cp "$pasteDirectory" "$finalDirectory"
        			logInfo "Se copio el archivo debido a que una de las carpetas tiene mas de $maxNumberOfAudios archivos"
        			echo "NO_EJECUTAR" > "$archivoControl"
        			echo -e "$mensaje" | msmtp -a office365 -t "$destinatarios" -f alarms@inconcert.global
        			exit 0
    			fi
            		logInfo "No se cumple la condicion de mas de $maxNumberOfAudios archivos en ninguna de las carpetas."
        	else
            		logInfo "El archivo de control indica que no se debe ejecutar la accion."
        	fi
    	else
        	logInfo "No se encontro el archivo de control."
    	fi

}

main
