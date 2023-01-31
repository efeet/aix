#!/bin/sh
#Script para OS AIX
#Probado en AIX 7.1, 7.2, 7.3
#Genera o elimina disco alterno
#
#Pasos
# -> Creacion de Disco Alterno.
# 1. Valida actual disco rootvg para obtener taman~o y cantidad.
# 2. Busca un disco libre de similar taman~o para utilizar como alterno, en caso de no existir da la posibilidad de utiizar otro disco mas grande.
# 3. Genera disco alterno.
# 4. Editar bootlist para regresar al disco anterior.
# 5. En caso de no existir discos libre o de mayor taman~o finaliza.
#
# -> Eliminacion de Disco Alterno.
# 1. Valida actual disco rootvg
# 2. Actualiza bootlist para utilizar actual disco rootvg
# 3. Busca y elimina el disco old_rootvg

#Array rootvg disks
set -A ROOTVG_DISK
#Array candidates disks
set -A CANDITATE_DISKS
#Array selected disks
set -A SELECT_DISKS
DISK_SIZE=1024
#Flag for rootvg
ROOTVG_COUNT=1
#Total rootvg disks
TOTAL_ROOTVG=0
#Flag candidates disks
CANDITATE_COUNT=1
#Total candidates disks
TOTAL_CANDIDATES=0

_validate_rootvg(){
	for i in $(lspv |  grep rootvg | awk '{ print $1 '})
	do
		ROOTVG_DISK[${ROOTVG_COUNT}]=$i
		ROOTVG_COUNT=$(eval expr $ROOTVG_COUNT + 1)
		ROOTVG_DISK[${ROOTVG_COUNT}]=$(getconf DISK_SIZE /dev/$i)
		ROOTVG_COUNT=$(eval expr $ROOTVG_COUNT + 1)
	done
}

_finding_disks(){
	for i in $(lspv | grep None | awk '{ print $1 '})
	do
		CANDITATE_DISKS[${CANDITATE_COUNT}]=$i
		CANDITATE_COUNT=$(eval expr $CANDITATE_COUNT + 1)
		CANDITATE_DISKS[${CANDITATE_COUNT}]=$(getconf DISK_SIZE /dev/$i)
		CANDITATE_COUNT=$(eval expr $CANDITATE_COUNT + 1)
	done
}

_calculate_disk_numbers(){
#	echo ${#ROOTVG_DISK[@]}
	TOTAL_ROOTVG=$(expr $(eval echo ${#ROOTVG_DISK[@]}) / 2 )
#	echo ${#CANDITATE_DISKS[@]}	
	TOTAL_CANDIDATES=$(expr $(eval echo ${#CANDITATE_DISKS[@]}) / 2 )
}



_validate_rootvg
_finding_disks
_calculate_disk_numbers
#_select_candidates

#_select_candidates(){
	VARLOOP1=0
	VARLOOP2=0
	VARNAME=1
	VARSIZE1=2
	VARSIZE2=2
	VARSELECT=1
	while [ $VARLOOP1 -lt $TOTAL_ROOTVG ]
	do
		echo "Looking disk for Size: " ${ROOTVG_DISK[$VARSIZE1]}
		VARLOOP2=0
		VARSIZE2=2
		while [ $VARLOOP2 -lt $TOTAL_CANDIDATES ]
		do
			echo "Candidate Size: " ${CANDITATE_DISKS[$VARSIZE2]} "Disk: " ${CANDITATE_DISKS[$(expr $VARSIZE2 - 1)]}
			if [[ ${CANDITATE_DISKS[$VARSIZE2]} -eq ${ROOTVG_DISK[$VARSIZE1]} ]]
			then
				SELECT_DISKS[$VARSELECT]=${CANDITATE_DISKS[$(expr $VARSIZE2 - 1)]}
				VARSELECT=$(eval expr $VARSELECT + 1)
			fi
			VARLOOP2=$(eval expr $VARLOOP2 + 1)
			VARSIZE2=$(eval expr $VARSIZE2 + 2)
		done
		VARLOOP1=$(eval expr $VARLOOP1 + 1)
		VARSIZE1=$(eval expr $VARSIZE1 + 2)
	done
#}

echo  ${#SELECT_DISKS[@]}
echo ${SELECT_DISKS[@]}

#0 1 2
#1 3 5
#2 4 6





















