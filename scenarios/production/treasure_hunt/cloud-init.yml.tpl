#cloud-config (basis)
repo_update: true
repo_upgrade: all
ssh_pwauth: yes
hostname: treasure-hunt
packages:
%{ for package in packages ~}
- ${package}
%{ endfor ~}
users:
- default
%{ for player in players ~}
- name: ${player.login}
  passwd: ${player.password.hash}
  lock_passwd: false
  shell: /bin/bash
%{ endfor ~}
runcmd:
- set -eu
- hostname treasure-hunt
- service ssh restart
