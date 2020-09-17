ENVS_FROM_LOCAL_EXEC=

%{ for key, value in items }
VAL="$(${value})"
ENVS_FROM_LOCAL_EXEC="export ${key}=$${VAL} $${ENVS_FROM_LOCAL_EXEC};"
%{ endfor }

export ENVS_FROM_LOCAL_EXEC
