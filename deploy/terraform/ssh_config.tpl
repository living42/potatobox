Host *
UserKnownHostsFile=/dev/null
StrictHostKeyChecking=no
TCPKeepAlive yes
ServerAliveInterval 15

%{for _, instances in servers ~}
%{ for instance in instances ~}
Host ${instance.name}
Hostname ${instance.public_ip}
User root
IdentityFile ${ssh_priv_key_file}

%{ endfor ~}
%{ endfor ~}
