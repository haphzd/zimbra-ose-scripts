#!/bin/bash

export log_file='/tmp/zm-compress-blobs.log'
compression_threshold='+1k' #minimal file size to apply compression (find command syntax); Zimbra default is 4096 bytes
older_than='180' #days
export store_root='/opt/zimbra/store/0/'

#rm -f /tmp/zm-compress-blobs.log
rm -f /tmp/zmstorage
echo '0' > /tmp/prev_id
#1 Check if possibly a WebDAV file - fast - id before dash in filename the same as previous file in sorted list
#2 Check if possibly a WebDAV file - slow - id before dash in filename not unique -- not doing that
#3 Check if actually mail - then compress
zmblobfilter()
{
    prev_id=$(< /tmp/prev_id)
    echo ""
    echo $1
    #echo "prev_id ${prev_id}"
    regex="\/([0-9]*)-[0-9]*.msg$"
    if [[ $1 =~ $regex ]]
    then
        blob_id="${BASH_REMATCH[1]}"
    else
        echo "Weird filename, will skip this file" >&2
        return 0
    fi

    if  [[ "$blob_id" = "$prev_id" ]]; then
        echo "Skipping versioned file (WebDAV)"
    else
        file $1 | grep "RFC 822 mail\|SMTP mail" && zmblobaction $1
    fi
    echo "$blob_id" > /tmp/prev_id
};

zmblobaction()
{
    echo "Gzipping file ${1}"
    echo -n "${1} $(date +%s -r ${1}) [ $(date -R -r ${1}) ] " >> $log_file
    numlinks=''
    if [[ $do_links = 1 ]]; then
	gzip_opt='-n -f'
        links=$(find $store_root -samefile $1)
        links_nodup=$(grep -v $1 <<< $links)
        #echo -e "Nodup\n$links_nodup"
        numlinks=$(echo "$links" | wc -l)
    else
	gzip_opt='-n'
    fi
    inode=''
    gzip $gzip_opt $1 2>&1 | tee -a $log_file
    if [ -s "${1}.gz" ]; then
        mv "${1}.gz" $1
        if [[ $do_links = 1 ]]; then inode=$(ls -li $1 | awk '{print $1}'); fi
        gzip -l $1 | tail -n 1 | awk -v n=$numlinks -v nn=$inode 'BEGIN { OFS="\t" }{print $2,$1,$3,n,nn}' >> $log_file
        for l in $links_nodup
        do
            #sc=$(awk '{print length}' <<< $(tail -n1 $log_file))
            printf "==%s\n" "$l $(date +%s -r $l) [ $(date -R -r $l)" >> $log_file
            #Force update link with a new inode of compressed file
            ln -f $1 $l
            echo "Updated hardlink."
        done
        echo "Done!"
    fi
};
export -f zmblobfilter;
export -f zmblobaction;
#https://stackoverflow.com/questions/5119946/find-exec-with-multiple-commands 
#find *.txt -exec bash -c 'multiple_cmd "$0"' {} \;

#find /opt/zimbra/store/ -type f -size +16k ! -mtime -120 -exec bash -c "zmblobfilter '{}'" \;
echo
echo "------------------------------------" >> $log_file
echo "Job started $(date +%Y-%m-%d+%H:%M:%S)" >> $log_file
echo -n "Processing path: ${store_root}, min_size: ${compression_threshold}, min_age_days: ${older_than}, hardlinks: " >> $log_file
if [[ $1 = '--hardlinks' ]]; then do_links='1'; echo 'yes' >> $log_file; else  do_links='0'; echo 'no' >> $log_file; fi
export do_links
echo "Below is the list of files compressed" >> $log_file
echo -n "Name Original_Timestamp Timestamp_RFC_5322 Original_size New_size Ratio" >> $log_file
if [[ $do_links = 1 ]]; then echo -n " Num_Links Inode" >> $log_file; fi
echo -e  "\n------------------------------------" >> $log_file
find $store_root -type f -size $compression_threshold ! -mtime "-${older_than}" | sort | tee /tmp/zmstorage | xargs -n1 -P1 bash -c 'zmblobfilter "$@"' _
echo "------------------------------------" >> $log_file
echo "Job finished $(date +%Y-%m-%d+%H:%M:%S)" >> $log_file
