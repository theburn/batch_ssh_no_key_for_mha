
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
./run.sh
```
