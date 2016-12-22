
## Usage

1. add `HOSTNAME` `IP ADDRESS` `SSH PORT` `USER NAME` `USER PASSWORD` to `list.txt`
For example:
```bash
Shell> cat list.txt
MySQL_MHA   192.168.1.1   22   root   111111
MySQL_1     192.168.1.2   22   root   111111
MySQL_2     192.168.1.3   22   root   111111
MySQL_3     192.168.1.4   22   root   111111
```

2. Then execute:
```bash
root> sh ./run.sh 7  # means all OS is CentOS 7.x
root> sh ./run.sh 6  # means all OS is CentOS 6.x

# if you want reboot all server
root> sh ./run.sh reboot
```

## Notice  

1. so far, Only supprot CentOS-7.x and  CentOS-6.x and need `root`;
2. if you use centos 6.x , please `yum install openssh-clients` first;
3. CentOS-6.x `ssh-copy-id` not support `non-22` port
