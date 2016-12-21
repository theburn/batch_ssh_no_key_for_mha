#!/bin/bash
RANDOM_STR_HOSTS=$(cat /dev/urandom | head -n 2 | md5sum  | cut -c 1-10)".hosts"

if [[ ! -d ./tmp ]];then
    mkdir ./tmp
else
    rm -rf ./tmp/*
fi

##
## Gen hosts file
##
while read line
do
    host_name=$(echo ${line} | awk '{print $1}')
    host_ip=$(echo ${line} | awk '{print $2}')
    echo "${host_name}    ${host_ip}" >> ./tmp/${RANDOM_STR_HOSTS}
done < ./list.txt


##
## scp hosts and cat to /etc/hosts
##
while read line
do
    host_ip=$(echo ${line} | awk '{print $2}')
    ssh_port=$(echo ${line} | awk '{print $3}')
    user=$(echo ${line} | awk '{print $4}')
    pass=$(echo ${line} | awk '{print $5}')

	expect << EOF
		spawn scp -P ${ssh_port} ./tmp/${RANDOM_STR_HOSTS} ${user}@${host_ip}:/tmp
		expect {
			"*yes/no" { send "yes\r"; exp_continue }
			"*password:" { send "$pass\r"; exp_continue }
			"#" { send "cat $RANDOM_STR_HOSTS >> /etc/hosts\r" }
		}
EOF

done < ./list.txt

##
## Gen id_rsa.pub
##
while read line
do
    host_ip=$(echo ${line} | awk '{print $2}')
    ssh_port=$(echo ${line} | awk '{print $3}')
    user=$(echo ${line} | awk '{print $4}')
    pass=$(echo ${line} | awk '{print $5}')

	expect << EOF
        spawn ssh -p ssh_port ${user}@${host_ip} "cd ~/.ssh && rm -rf id_rsa*;ssh-keygen -t rsa"
		expect {
		 "*yes/no" { send "yes\r"; exp_continue }
		 "*password:" { send "$pass\r"; exp_continue  }
		 "Enter file in which to save the key*" { send "\n\r"; exp_continue }
		 "Overwrite*" { send "y\n"; exp_continue } 
		 "Enter passphrase (empty for no passphrase):" { send "\n\r"; exp_continue }
		 "Enter same passphrase again:" { send "\n\r" }
		}
EOF

done < ./list.txt


##
## ssh-copy-id to other hosts
##
while read line
do
    host_ip=$(echo ${line} | awk '{print $2}')
    ssh_port=$(echo ${line} | awk '{print $3}')
    user=$(echo ${line} | awk '{print $4}')
    pass=$(echo ${line} | awk '{print $5}')

    while read line
    do

        target_host_ip=$(echo ${line} | awk '{print $2}')
        target_ssh_port=$(echo ${line} | awk '{print $3}')
        target_user=$(echo ${line} | awk '{print $4}')
        target_pass=$(echo ${line} | awk '{print $5}')

        if [[ $target_host_ip  == $host_ip ]];then
            continue
        fi

        expect << EOF
            spawn ssh -p ssh_port ${user}@${host_ip} "ssh-copy-id -p -i ~/.ssh/id_rsa.pub ${target_user}@${target_host_ip}"
            expect {
             "*yes/no" { send "yes\r"; exp_continue }
             "*password:" { send "$pass\r"; exp_continue  }
            }
EOF

    done < ./list.txt
done < ./list.txt


##
## Get KNOW_HOSTS by HOSTNAME
##
while read line
do
    host_name=$(echo ${line} | awk '{print $1}')
    ssh_port=$(echo ${line} | awk '{print $3}')
    user=$(echo ${line} | awk '{print $4}')
    pass=$(echo ${line} | awk '{print $5}')
    prompt='#'
    if [[ ${user} == 'root' ]];then
        prompt='#'
    else
        prompt='$'
    fi
    expect << EOF
        set timeout  300
        spawn -noecho ssh  -p ${port} ${user}@${host_name}
        expect  {
           "(yes/no)?" {send "yes\r";exp_continue}
           "password:" {send "\x03\r"; exp_continue}
           "${prompt}" {send "exit\r"}
        }
        set timeout  300
        expect "100%"
EOF
done < ./list.txt