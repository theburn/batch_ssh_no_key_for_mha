#!/bin/bash


OS_VERSION=$1
INSTALL_RPM=$2

if [[ ${INSTALL_RPM} == "" ]];then
    INSTALL_RPM=1
fi

RPMS=""

function usage()
{
    echo "$0  6|7  1 "
    echo "Example :  $0 7 (means os is centos7.x and install rpms)"
    echo "           $0 7 0  (means dont't install rpms)" 
    echo "           $0 reboot  (means dont't install rpms)" 
}


LOCAL_IPS=""
function get_local_ips()
{
    LOCAL_IPS=$(ip addr | grep -E  "\<inet\>" | grep -v "127.0.0.1" | awk -F [/\ ] '{print $6}')
}

function do_reboot()
{
    get_local_ips
    SELF_IP=""
    while read line
    do
        host_name=$(echo ${line} | awk '{print $1}')
        host_ip=$(echo ${line} | awk '{print $2}')
        ssh_port=$(echo ${line} | awk '{print $3}')
        user=$(echo ${line} | awk '{print $4}')
        pass=$(echo ${line} | awk '{print $5}')

        if [[ ${SELF_IP} == "" ]];then
            for i in ${LOCAL_IPS}
            do
                if [[ "${host_ip}" == ${i} ]];then
                    SELF_IP=${i}
                fi
            done
        fi

        if [[ ${SELF_IP} == ${host_ip} ]];then
            continue
        fi

        expect << EOF
            set timeout 300
            spawn ssh -p ${ssh_port} ${user}@${host_ip} "reboot"
            expect {
                 "*yes/no" { send "yes\r"; exp_continue }
                 "*password:" { send "$pass\r";}
                 "closed" { send "\n\r";}
            }
            expect eof
EOF

    echo "--------------- host_ip = ${host_ip} rebooting... ---------------"
    done < ./list.txt
    
    read  -p "Do you want to reboot local host (y/n)?" r
    if [[ ${r} =~ ^"y" || ${r} =~ ^"Y" ]];then
        echo "--------------- host_ip = ${SELF_IP} rebooting... ---------------"
        reboot
    fi
exit 0
}


if [[ $OS_VERSION == "" ]];then
    usage
    exit 2
elif [[ $OS_VERSION == "7" ]];then
    RPMS="CentOS7.x"
    SSH_COPY_ID="ssh-copy-id -p "
elif [[ $OS_VERSION == "6" ]];then
    RPMS="CentOS6.x"
    SSH_COPY_ID="ssh-copy-id"
elif [[ $OS_VERSION == "reboot" ]];then
    do_reboot
else
    usage
    exit 3
fi


##
## rpm install expect and tcl
##

if [[ ${INSTALL_RPM} -eq 1 ]];then
    rpm -iUvh ./rpm/${RPMS}/*.rpm --force
fi

CURDIR=$(pwd)

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
    host_name=$(echo ${line} | awk '{print $1}')
    host_ip=$(echo ${line} | awk '{print $2}')
    ssh_port=$(echo ${line} | awk '{print $3}')
    user=$(echo ${line} | awk '{print $4}')
    pass=$(echo ${line} | awk '{print $5}')

    prompt='#'
    if [[ ${user} == 'root' ]];then
        prompt='#'
    else
        prompt='$'
    fi

    # Close SELinux 
#    expect << EOF
#        set timeout 300
#        spawn ssh -p ${ssh_port} ${user}@${host_ip} "setenforce 0"
#        expect {
#             "*yes/no" { send "yes\r"; exp_continue }
#             "*password:" { send "$pass\r";}
#        }
#        expect eof
#EOF
#

	expect << EOF
        set timeout 300
		spawn scp -P ${ssh_port} ${CURDIR}/tmp/${RANDOM_STR_HOSTS} ${user}@${host_ip}:/tmp/
		expect {
			"*yes/no" { send "yes\r"; exp_continue}
			"*password:" { send "$pass\r"; exp_continue}
            "${prompt}"  {send "exit\r"}
            "*hosts" exp_continue
		}
        expect "100%"
        expect eof
EOF

	expect << EOF
        set timeout 300
		spawn ssh -p ${ssh_port} ${user}@${host_ip}
		expect {
			"*yes/no" { send "yes\r"; exp_continue}
			"*password:" { send "$pass\r"}
		}

        expect { 
            "${prompt}" { send "cat /tmp/${RANDOM_STR_HOSTS} >> /etc/hosts;cat /etc/hosts\r" }
        }

        expect "${prompt}" { send "exit\r" }

        expect eof

EOF


    if [[ ${OS_VERSION} -ge 7 ]];then 
        expect << EOF
            set timeout 300
            spawn ssh -p ${ssh_port} ${user}@${host_ip} "echo ${host_name} > /etc/hostname"
            expect {
                 "*yes/no" { send "yes\r"; exp_continue }
                 "*password:" { send "$pass\r";}
            }
            expect eof
EOF
    else 
        expect << EOF
            set timeout 300
            spawn ssh -p ${ssh_port} ${user}@${host_ip} "sed -i 's/HOSTNAME=.*/HOSTNAME=${host_name}/g' /etc/sysconfig/network;"
            expect {
                 "*yes/no" { send "yes\r"; exp_continue }
                 "*password:" { send "$pass\r";}
            }
            expect eof
EOF

    fi

    if [[ ${INSTALL_RPM} -eq 1 ]];then
        expect << EOF
            set timeout 300
            spawn sh -c "scp -P ${ssh_port}  -r ${CURDIR}/rpm ${user}@${host_ip}:/tmp/"
            expect {
                "*yes/no" { send "yes\r"; exp_continue}
                "*password:" { send "$pass\r"}
            }

            expect "100%"
            expect eof
EOF

        expect << EOF
            set timeout 300
            spawn ssh -p ${ssh_port} ${user}@${host_ip} 
            expect {
                "*yes/no" { send "yes\r"; exp_continue}
                "*password:" { send "$pass\r"}
            }
            expect "${prompt}" { send "rpm -iUvh /tmp/rpm/${RPMS}/\*.rpm --force\r" }

            expect { 
                "*rpm" exp_continue
                "${prompt}" { send "exit\r" }
            }

            expect eof
EOF
    fi

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

        expect eof
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

       # if [[ $target_host_ip  == $host_ip ]];then
       #     echo "------------ same host, skip target_host_name = ${target_host_name} -------------"
       #     continue
       # fi

        prompt='#'
        if [[ ${user} == 'root' ]];then
            prompt='#'
        else
            prompt='$'
        fi

	if [[ $OS_VERSION == "7" ]];then
	    SSH_COPY_ID="ssh-copy-id -p ${target_ssh_port}"
	elif [[ $OS_VERSION == "6" ]];then
	    SSH_COPY_ID="ssh-copy-id"
	else
	    usage
	    exit 3
	fi



        expect << EOF
            set timeout 300
            spawn ssh -p ${ssh_port} ${user}@${host_ip}
            expect {
                 "*yes/no" { send "yes\r"; exp_continue }
                 "password:" { send "$pass\r"; exp_continue }
                 "${prompt}" {
                    send "${SSH_COPY_ID} -i ~/.ssh/id_rsa.pub ${target_user}@${target_host_ip}\n"
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
                            expect {
                                "${prompt}" {send "exit\r"}
                            }
                        }
                    }
                }
            }
            expect eof

            sleep 1
            puts stderr "\n--------- ssh-copy-id from ${host_ip}  to ${target_host_ip} --------\n"


EOF

    done < ./list.txt
done < ./list.txt

echo "#######################################################################################"
echo -e "#Notice : If you want to display the \033[33mhost name\e[0m in PS1[root@{hostname}], Please \e[5m\033[31mreboot\e[0m \e[25m#"
echo "#######################################################################################"
