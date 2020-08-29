Host *
UserKnownHostsFile=/dev/null
StrictHostKeyChecking=no
TCPKeepAlive yes
ServerAliveInterval 15

%{ for host, instance in core_nodes ~}
Host ${host}
Hostname ${instance.public_ip}
User root
IdentityFile ${ssh_priv_key_file}

%{ endfor ~}