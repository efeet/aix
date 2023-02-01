#!/bin/sh
#Script para OS AIX
#Probado en AIX 7.1, 7.2, 7.3
#Genera o elimina disco alterno
#
#Pasos
# -> Creacion de Disco Alterno.
# Automatico:
# 1. Valida actual disco rootvg para obtener taman~o y cantidad.
# 2. Busca un disco libre de similar taman~o para utilizar como alterno, en caso de no existir da la posibilidad de utiizar otro disco mas grande.
# 3. Genera disco alterno.
# 4. Editar bootlist para regresar al disco anterior.
# 5. En caso de no existir discos libre o de mayor taman~o finaliza.
# Manual:
# 1. Valida actual disco rootvg para obtener taman~o y cantidad.
# 2. Busca un disco libre o de similar taman~o para utilizar como alterno, presenta las opciones para escoger el/los disco(s).
# 3. Genera disco alterno.
# 4. Editar bootlist para regresar al disco anterior.
# 5. En caso de no existir discos libre o de mayor taman~o finaliza.
#
# -> Eliminacion de Disco Alterno.
# 1. Valida actual disco rootvg
# 2. Actualiza bootlist para utilizar actual disco rootvg
# 3. Busca y elimina el disco old_rootvg
#
# Modo de ejecucion:
# ./alt-disk.sh [option]
#	-> Options:
#			AUTO = Crea automaticamente los discos alternos.
#					Toma los discos de `lspv` marcados con None y busca taman~o similar o mayor.
#			MANUAL = Solicita el nombre de los discos para Crear disco alterno.
#			DELETE = Elimina discos alternos marcados como "altinst_rootvg" y "old_rootvg", asegura el bootlist antes de eliminar.

#Array rootvg disks
set -A ROOTVG_DISK
#Array candidates disks
set -A CANDITATE_DISKS
#Array selected disks
set -A SELECT_DISKS
#DISK_SIZE=1024
#Flag for rootvg
ROOTVG_COUNT=1
#Total rootvg disks
TOTAL_ROOTVG=0
#Flag candidates disks
CANDITATE_COUNT=1
#Total candidates disks
TOTAL_CANDIDATES=0
#Flag to select method "AUTO/MANUAL"
SELECT_METHOD=AUTO
#Array final disks
set -A FINAL_DISKS


_get_rootvg_info(){
	for i in $(lspv |  grep rootvg | awk '{ print $1 '})
	do
		ROOTVG_DISK[${ROOTVG_COUNT}]=$i
		ROOTVG_COUNT=$(eval expr $ROOTVG_COUNT + 1)
		ROOTVG_DISK[${ROOTVG_COUNT}]=$(getconf DISK_SIZE /dev/$i)
		ROOTVG_COUNT=$(eval expr $ROOTVG_COUNT + 1)
	done
}

_finding_free_disks(){
	for i in $(lspv | grep None | awk '{ print $1 '}); do printf "%s %s\n" $(echo $i) $(getconf DISK_SIZE /dev/$i); done > /tmp/salida
	for i in $(cat /tmp/salida | sort -k2)
	do
		CANDITATE_DISKS[${CANDITATE_COUNT}]=$i
		CANDITATE_COUNT=$(eval expr $CANDITATE_COUNT + 1)
		#CANDITATE_DISKS[${CANDITATE_COUNT}]=$(getconf DISK_SIZE /dev/$i)
		#CANDITATE_COUNT=$(eval expr $CANDITATE_COUNT + 1)
	done
}

_calculate_disk_numbers(){
#	echo ${#ROOTVG_DISK[@]}
	TOTAL_ROOTVG=$(expr $(eval echo ${#ROOTVG_DISK[@]}) / 2 )
#	echo ${#CANDITATE_DISKS[@]}	
	TOTAL_CANDIDATES=$(expr $(eval echo ${#CANDITATE_DISKS[@]}) / 2 )
}

_show_candidates_disks(){
	#set -x
	VARLOOP1=0
	VARSIZE1=2
	VARSELECT=1
	echo "Total disk in rootvg: "$TOTAL_ROOTVG
	echo ""
	while [ $VARLOOP1 -lt $TOTAL_ROOTVG ]
	do
		echo "Number: " $(eval expr $VARLOOP1 + 1) " - Disk: " ${ROOTVG_DISK[$(expr $VARSIZE1 - 1)]} " - size: " ${ROOTVG_DISK[$VARSIZE1]}
		VARLOOP2=0
		VARSIZE2=2
		while [ $VARLOOP2 -lt $TOTAL_CANDIDATES ]
		do
			echo "Candidate Disk:     " ${CANDITATE_DISKS[$(expr $VARSIZE2 - 1)]} " - Size: " ${CANDITATE_DISKS[$VARSIZE2]}
			if [ ${CANDITATE_DISKS[$VARSIZE2]} -eq ${ROOTVG_DISK[$VARSIZE1]} ] || [ ${CANDITATE_DISKS[$VARSIZE2]} -gt ${ROOTVG_DISK[$VARSIZE1]} ] 
			then
				SELECT_DISKS[$VARSELECT]=${CANDITATE_DISKS[$(expr $VARSIZE2 - 1)]}
				VARSELECT=$(eval expr $VARSELECT + 1)
			fi
			VARLOOP2=$(eval expr $VARLOOP2 + 1)
			VARSIZE2=$(eval expr $VARSIZE2 + 2)
		done
		VARLOOP1=$(eval expr $VARLOOP1 + 1)
		VARSIZE1=$(eval expr $VARSIZE1 + 2)
		echo ""
		echo ""
	done
}

_auto_select_disk(){
	VARLOOP1=0
	VARSELECT=1
	echo "MODE: Auto select disk..."	
	while [ $VARLOOP1 -lt $TOTAL_ROOTVG ]
	do
		FINAL_DISKS[$VARSELECT]=${SELECT_DISKS[$VARSELECT]}
		VARSELECT=$(eval expr $VARSELECT + 1)
		VARLOOP1=$(eval expr $VARLOOP1 + 1)
	done
}

_manual_select_disk(){
	VARLOOP1=0
	VARSELECT=1
	echo "Please select disks from Candidate Disks"
	echo ""
	while [ $VARLOOP1 -lt $TOTAL_ROOTVG ]
	do
		echo "Disk number: " $(expr $VARLOOP1 + 1)
		printf 'Name: '
		read -r FINAL_DISKS[$VARSELECT]
		VARSELECT=$(eval expr $VARSELECT + 1)
		VARLOOP1=$(eval expr $VARLOOP1 + 1)
	done
}

_set_bootlist(){
	ROOTVG=$(lsvg -p rootvg | grep hdisk | awk '{ print $1 '})
	EXEC=$(echo $ROOTVG | awk '{ print "sudo bootlist -m normal \"" $0 "\"" '})
	echo $EXEC |  sh
	sudo bootlist -m normal -o
}

_create_alt_disk(){
	echo "sudo alt_disk_copy -d \""${FINAL_DISKS[@]}"\"" | sh
}

_delete_alt_disk(){
	echo "sudo alt_rootvg_op -X altinst_rootvg" | sh
	echo "sudo alt_rootvg_op -X old_rootvg" | sh
}


if [ $# -eq 0 ]
  then
	echo "No arguments supplied"; exit 1
fi

case $1 in
	'AUTO')
		_get_rootvg_info
		_finding_free_disks
		_calculate_disk_numbers
		_show_candidates_disks
		_auto_select_disk
		_create_alt_disk
		_set_bootlist
	;;
	'MANUAL')
		_get_rootvg_info
		_finding_free_disks
		_calculate_disk_numbers
		_show_candidates_disks
		_manual_select_disk
		_create_alt_disk
		_set_bootlist
	;;
	'DELETE')
		_delete_alt_disk
		_set_bootlist
	;;
	*)
		echo "Invalid arguments."
		exit 1
	;;
esac


#echo "-------------------------"
#echo ""
#echo  ${#SELECT_DISKS[@]}
#echo ${SELECT_DISKS[@]}
#echo "Final..........."
#echo  ${#FINAL_DISKS[@]}
#echo ${FINAL_DISKS[@]}





















