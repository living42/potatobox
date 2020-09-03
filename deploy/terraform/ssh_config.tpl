Host *
UserKnownHostsFile=/dev/null
StrictHostKeyChecking=no
TCPKeepAlive yes
ServerAliveInterval 15

Host jumpserver
Hostname ${jumpserver.ip}
User root
IdentityFile ${ssh_priv_key_file}

%{ for instance in internal_instances ~}
Host ${instance.name}
Hostname ${instance.private_ip}
User root
IdentityFile ${ssh_priv_key_file}
ProxyJump jumpserver

%{ endfor ~}
