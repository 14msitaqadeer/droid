#!/bin/bash
#This script will copy maas superuser PUB key to infra host
 cat > /tmp/ssh_copy_id.py <<EOF
import pexpect, sys
child = pexpect.spawn("scp -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no -o UserKnownHostsFile=/dev/null /var/lib/maas/.ssh/id_rsa.pub ubuntu@172.19.36.135:~/.ssh/authorized_keys", logfile=sys.stdout, timeout=None)
child.expect(".*password: ")
child.sendline("ubuntu")
child.expect(pexpect.EOF, timeout=None)
EOF
python /tmp/ssh_copy_id.py
