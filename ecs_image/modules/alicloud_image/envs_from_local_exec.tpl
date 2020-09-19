%{ for key, value in items }
VAL="$(${value})"
INJECT_SCRIPTS="export ${key}=$${VAL} $${INJECT_SCRIPTS};"
%{ endfor }

export INJECT_SCRIPTS
