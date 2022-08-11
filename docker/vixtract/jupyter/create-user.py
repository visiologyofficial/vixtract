#!/usr/bin/env python
import crypt
import os
import sys

if __name__ == '__main__':
    if len(sys.argv) <= 1:
        sys.stderr.write('Usage : create-user.py <username>\n')
        sys.exit(1)
    if 'DEFAULT_USER_PASSWORD' in os.environ:
        default_password = os.environ['DEFAULT_USERS_PASSWORD'] 
    else:
        default_password = 'vixtract'

    username = sys.argv[1]
    os.system("useradd -p "+crypt.crypt(default_password,"22")+" -m "+username)


