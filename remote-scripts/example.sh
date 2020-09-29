[servers]
host1

# DO NOT CHANGE ANYTHING BELOW THIS LINE
[servers:vars]
pbench_repo_url_prefix = https://copr-be.cloud.fedoraproject.org/results/ndokos

# where to get the key
pbench_key_url = http://git.app.eng.bos.redhat.com/git/pbench.git/plain/agent/{{ pbench_configuration_environment }}/ssh
# where to put it
pbench_key_dest = /opt/pbench-agent/

# where to get the config file
pbench_config_url = http://git.app.eng.bos.redhat.com/git/pbench.git/plain/agent/{{ pbench_configuration_environment }}/config
# where to put it
pbench_config_dest = /opt/pbench-agent/config/

pbench_config_files = '["pbench-agent.cfg"]'

owner = pbench
group = pbench