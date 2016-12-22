#!/bin/bash


OS_VERSION=$1
RPMS=""

if [[ $OS_VERSION == "" ]];then
    echo "$0  6|7   [ CentOS Version ]"
    echo "Example :  $0 7"
    exit 2

elif [[ $OS_VERSION == "7" ]];then
    RPMS="CentOS7.x"
elif [[ $OS_VERSION == "6" ]];then
    RPMS="CentOS6.x"
else
    echo "$0  6|7   [ CentOS Version ]"
    echo "Example :  $0 7"
    exit 3
fi


##
## rpm install expect and tcl
##

rpm -iUvh ./rpm/${RPMS}/*.rpm --force


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
    echo "${host_ip}    ${host_name}" >> ./tmp/${RANDOM_STR_HOSTS}
done < ./list.txt


##
## scp hosts and cat to /etc/hosts
## scp rpms and install
##
while read line
do
    host_ip=$(echo ${line} | awk '{print $2}')
    ssh_port=$(echo ${line} | awk '{print $3}')
    user=$(echo ${line} | awk '{print $4}')
    pass=$(echo ${line} | awk '{print $5}')

	expect << EOF
        set timeout 300
		spawn scp -P ${ssh_port} ./tmp/${RANDOM_STR_HOSTS} ${user}@${host_ip}:/tmp
		expect {
			"*yes/no" { send "yes\r"; exp_continue }
			"*password:" { send "$pass\r"}
		}
EOF

	expect << EOF
        set timeout 300
		spawn ssh -p ${ssh_port} ${user}@${host_ip} "cat /tmp/${RANDOM_STR_HOSTS} >> /etc/hosts"
		expect {
			"*yes/no" { send "yes\r"; exp_continue }
			"*password:" { send "$pass\r"}
		}
EOF

    expect << EOF
        set timeout 300
        spawn scp -r -P ${ssh_port} ./rpm ${user}@${host_ip}:/tmp
        expect {
            "*yes/no" { send "yes\r"; exp_continue }
            "*password:" { send "$pass\r"}
        }
EOF

	expect << EOF
        set timeout 300
		spawn ssh -p ${ssh_port} ${user}@${host_ip} "cd /tmp/rpm/${RPMS};rpm -iUvh ./*.rpm --force"
		expect {
			"*yes/no" { send "yes\r"; exp_continue }
			"*password:" { send "$pass\r"}
		}
        sleep 1
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
        set timeout 300
        spawn ssh -p ${ssh_port} ${user}@${host_ip} "cd ~/.ssh && rm -rf id_rsa*;ssh-keygen -t rsa"
		expect {
		 "*yes/no" { send "yes\r"; exp_continue }
		 "*password:" { send "$pass\r"; exp_continue  }
		 "Enter file in which to save the key*" { send "\n\r"; exp_continue }
		 "Overwrite*" { send "y\n"; exp_continue } 
		 "Enter passphrase (empty for no passphrase):" { send "\n\r"; exp_continue }
		 "Enter same passphrase again:" { send "\n\n\r" }
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
        target_host_name=$(echo ${line} | awk '{print $1}')
        target_host_ip=$(echo ${line} | awk '{print $2}')
        target_ssh_port=$(echo ${line} | awk '{print $3}')
        target_user=$(echo ${line} | awk '{print $4}')
        target_pass=$(echo ${line} | awk '{print $5}')

        if [[ $target_host_ip  == $host_ip ]];then
            echo "------------ same host, skip target_host_name = ${target_host_name} -------------"
            continue
        fi

        prompt='#'
        if [[ ${user} == 'root' ]];then
            prompt='#'
        else
            prompt='$'
        fi

        expect << EOF
            set timeout 300
            spawn ssh -p ${ssh_port} ${user}@${host_ip}
            expect {
                 "*yes/no" { send "yes\r"; exp_continue }
                 "password:" { send "$pass\r"; exp_continue }
                 "${prompt}" {
                    send "ssh-copy-id -p ${target_ssh_port} -i ~/.ssh/id_rsa.pub ${target_user}@${target_host_ip}\n"
                    expect {
                        "*yes/no" { send "yes\r"; exp_continue }
                        "password:" { send "$target_pass\r"; exp_continue }
                        "${prompt}" { 
                            send "ssh -p ${target_ssh_port} ${target_user}@${target_host_name}\r"
                            expect {
                                "*yes/no" { send "yes\r"; exp_continue }
                                "password:" { send "$target_pass\r"; exp_continue }
                                "${prompt}" {send "exit\r"}
                            }
                        }
                    }
                }
            }
            sleep 1
            puts stderr "\n--------- ssh-copy-id from ${host_ip}  to ${target_host_ip} --------\n"

EOF

    done < ./list.txt
done < ./list.txt

