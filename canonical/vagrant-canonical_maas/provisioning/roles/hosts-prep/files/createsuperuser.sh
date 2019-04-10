#!/bin/bash
#This script will create super user
cat > /tmp/createsuperuser.py <<DELIM__
import pexpect, sys
child = pexpect.spawn("sudo maas-region-admin createsuperuser --email=abc@xyz.com --username=root", logfile=sys.stdout, timeout=None)
child.expect("Password: ")
child.sendline("root")
child.expect("Password ")
child.sendline("root")
child.expect(pexpect.EOF, timeout=None)
DELIM__
python /tmp/createsuperuser.py

