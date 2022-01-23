#!/bin/bash
ansible-galaxy role list 2>/dev/null | grep -q ansible-role-k3s || ansible-galaxy role install git+https://github.com/PyratLabs/ansible-role-k3s
ansible-playbook k3s-playbook.yml -i inventory.ini -K
