#!/bin/sh
#Script get Pre/Pos server info and compare.
#Only test in AIX, VIOS
#Power by Uzziel Sanchez - https://github.com/efeet
#Feb 2023
#Ejecucion:
# ./comandosv2
# 	-> Seleccionar en el Menu la opcion.
# ./comandosv2 [PRE|pre] o [POS|pos]
# 	-> En base a lo que se quiera realizar pre o pos info.
#
# Importante ejecutar con root para obtener toda la info completa.
# si no quieren ejecutar con root siempre quitar la validacion al final del archivo.
#

HOSTNAME=$(uname -n)
DATE=$(date +%d%b%y)

#Create Paths
#BASE_PATH="/fsresp-so/Unix_Tsystems/scripts/Patches/Comandos_v2"
#Esta ruta define donde se guardaran los archivos generados, se podria guardar en el fsresp-so para tener un respaldo igual.
mkdir -p /tmp/comandosv2
BASE_PATH="/tmp/comandosv2"
mkdir -p $BASE_PATH/$DATE/$HOSTNAME/pre/txt $BASE_PATH/$DATE/$HOSTNAME/pos/txt
PRETXTPATH=$BASE_PATH/$DATE/$HOSTNAME/pre/txt
POSTXTPATH=$BASE_PATH/$DATE/$HOSTNAME/pos/txt

function _get_cluster_info {
	echo "Getting Cluster info...."
	#Asigna valor a TXT con el nombre del evento PRE o POS
    if [[ $1 = "PRE" ]]
    then
        TXT="${PRETXTPATH}/pre"
    else
        TXT="${POSTXTPATH}/pos"
    fi
	/usr/es/sbin/cluster/clstat -o >  ${TXT}_clstat.txt
	/usr/es/sbin/cluster/utilities/clRGinfo >  ${TXT}_clrginfo.txt
	/usr/es/sbin/cluster/utilities/clRGinfo -m >  ${TXT}_clrginfo-mon.txt
}


function _get_vios_info {
	echo "Getting VIOS info...."
	#Asigna valor a TXT con el nombre del evento PRE o POS
    if [[ $1 = "PRE" ]]
    then
        TXT="${PRETXTPATH}/pre"
    else
        TXT="${POSTXTPATH}/pos"
    fi
	lsdev -Cc adapter| grep -i ent >  ${TXT}_lsdev-adapters.txt
	lsdev -Cc adapter| grep -i ethernet >  ${TXT}_lsdev-ethernet.txt
	lsdev -Cc adapter| grep -i etherchannel >  ${TXT}_lsdev-etherchannel.txt
	lsdev -Cc adapter | grep -i shared >  ${TXT}_lsdev-shared.txt
	for i in $(lsdev -Cc adapter | grep -i shared | sort | awk '{ print $1 '})
	do
		echo "Shared Ethernet Adapter: "$i
		entstat -d $i | grep -E "Driver Flags|Link Status|State|Port VLAN ID|VLAN Tag IDs"
		echo "---------------------------------------------------------------------"
	done > ${TXT}_shared-adapter-info.txt
	lsdev -Cc adapter | grep -i fcs  >  ${TXT}_lsdev-fcs.txt
	/usr/ios/cli/ioscli lsmap -npiv -all -fmt "," | sort -k2 | awk -F"," '{ split($2,C,"-"); print $7"|"$1"|"$3"|"C[3]"|"$11 }' > ${TXT}_npiv-mapping.txt
	/usr/ios/cli/ioscli lsmap -npiv -all -fmt "," | sort -k2 | awk -F"," '{ split($2,C,"-"); print $7"|"$1"|"$3"|"C[3]"|"$11 }' > ${TXT}_npiv-mapping-lpar.txt
}

function _get_comun_info {
    #set -x
	echo "Getting basic information..."
    #Asigna valor a TXT con el nombre del evento PRE o POS
    if [[ $1 = "PRE" ]]
    then
        TXT="${PRETXTPATH}/pre"
    else
        TXT="${POSTXTPATH}/pos"
    fi
    #echo ${TXT}_uname.txt
    #read
    uname -n >  ${TXT}_uname.txt
    oslevel -s > ${TXT}_oslevel.txt
    uptime > ${TXT}_uptime.txt
    who -b > ${TXT}_lastreboot.txt
    lparstat > ${TXT}_lparstat.txt
    lsps -a > ${TXT}_swap.txt
    lsvg -o | sort -n > ${TXT}_lsvg.txt
    lspv | sort -k3 > ${TXT}_lspv.txt
    echo "Total: "$(lspv | wc -l) >> ${TXT}_lspv.txt
    df -gI | sort -k6 > ${TXT}_filesystems.txt
    df -gI | grep : | sort -k6 > ${TXT}_nfs.txt
    exportfs > ${TXT}_exportfs.txt
    cat /etc/exports > ${TXT}_etcexports.txt
    df -gI | grep "\/" | sort -k1 | awk '{ print $1 }' > ${TXT}_LVs.txt
    df -gI | grep "\/" | sort -k6 | awk '{ print $6 }' > ${TXT}_monutpoint.txt
    ifconfig -a | sort > ${TXT}_networking.txt
    netstat -nr | sort >> ${TXT}_networking.txt
    lspath | grep -v Enabled > ${TXT}_lspath.txt
    ntpq -p > ${TXT}_ntp.txt
    ls -lrt /etc/ssh/sshd_config* > ${TXT}_sshdconfig.txt
	lssrc -a | grep -i active > ${TXT}_lssrc_active.txt
	lssrc -a | grep -v active > ${TXT}_lssrc_noactive.txt
	lssrc -a | grep -i rsct > ${TXT}_rsct.txt
	ps -ef | grep -i dsm | grep -iv grep > ${TXT}_dsm.txt
	lsdev -Cc iocp > ${TXT}_iocp.txt
	cat /etc/inetd.conf | grep -i caa > ${TXT}_inetd-caa.txt
	lsdev | sort > ${TXT}_lsdev.txt
	for i in $(lsdev -Cc adapter | grep -i fcs | sort | awk '{ print $1 '})
	do
		printf "%s - " $i
		lscfg -vpl $i | grep "Network Address" | awk -F. '{ print $NF '}
	done > ${TXT}_fcs-wwn.txt
	for i in $(lsdev | grep hdisk | sort | awk '{ print $1'})
	do
		printf "%s - " $i
		lsmpio -qal $i | grep "Volume Serial:" | awk '{ print $3 '}
	done > ${TXT}_lsmpio-uuids.txt
	for i in $(lsdev | grep hdisk | sort | awk '{ print $1'})
	do
		printf "%s - " $i
		lscfg -vpl $i | grep "Serial Number" | awk -F. '{ print $NF '}
	done > ${TXT}_lscfg-uuids.txt


	echo "Is VIOS?"
	if /usr/ios/cli/ioscli ioslevel > /dev/null 2>&1
	then
		_get_vios_info $1
	else
		echo "It's not VIOS"
	fi
	
	echo "Is Cluster?"
	if /usr/es/sbin/cluster/utilities/clRGinfo > /dev/null 2>&1
	then
		_get_cluster_info $1
	else
		echo "It's not Cluster"
	fi
}

function _compare_pre_pos {
	find $PRETXTPATH -type f -print > $BASE_PATH/list-pre.txt
	find $POSTXTPATH -type f -print > $BASE_PATH/list-pos.txt
	paste $BASE_PATH/list-pre.txt $BASE_PATH/list-pos.txt > $BASE_PATH/compare.txt
IFS='
'
	for i in $(cat $BASE_PATH/compare.txt)
	do
		echo "Comparando........ " $i
		echo "diff "$i | sh
		echo "===================================================================================================================================="
		echo ""
	done
}

function _opt_main {
    #set -x
    clear
    echo "-------------------------------------------------------------------------"
    echo "------------------> Script for Pre and Pos Patching <--------------------"
    echo "--------------------- "$(date)" ----------------------"
    echo ""
    echo "Select the option:"
    echo "1) ->PRE-Info."
    echo "2) ->POS-Info."
    read -r opt
    case $opt in
        '1')
            _get_comun_info "PRE"
        ;;
        '2')
            _get_comun_info "POS"
			_compare_pre_pos
        ;;
        *)
            echo "Please check execute sintax...."
            exit 1
        ;;
    esac
}

if [ $(whoami) = "root" ]
then
	case $1 in
        'PRE')
            _get_comun_info "PRE"
        ;;
		'pre')
            _get_comun_info "PRE"
        ;;
        'POS')
            _get_comun_info "POS"
			_compare_pre_pos
        ;;
		'pos')
            _get_comun_info "POS"
			_compare_pre_pos
        ;;
        *)
            _opt_main
        ;;
    esac
else
	echo "Try run with root for get all info.."
	exit 1
fi

