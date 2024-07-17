#!/bin/bash
############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "Usage: axon-agent-setup [options...]"
   echo " -v     The Cassandra version"
   echo " -c     The Cassandra Config Path"
   echo " -b     The Cassandra Bin Path where nodetool is installed. Nodetool is used for draining before a restart"
   echo " -u     The Cassandra Linux User"
   echo " -g     The Cassandra Linux Group"
   echo " -r     Restart Cassandra"
   echo " -a     The Cassandra Native Transport Address"
   echo " -p     The Cassandra Native Transport Port"
   echo " -k     The AxonOps Agent Key"
   echo " -o     The AxonOps Organization"
   echo " -j     The Java version that Cassandra is configured to use e.g 8 or 11"
   echo " -h     Print this Help."
   echo
}

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":h:v:c:b:u:g:r:a:p:k:o:j:" option; do
   case $option in
      h) # display Help
        Help
        exit;;
      v) cassandra_version=$OPTARG;;
      c) cassandra_config_path=$OPTARG;;
      b) cassandra_bin_path=$OPTARG;;
      u) cassandra_user=$OPTARG;;
      g) cassandra_group=$OPTARG;;
      r) cassandra_restart=$OPTARG;;
      a) cassandra_native_transport_address=$OPTARG;;
      p) cassandra_native_transport_port=$OPTARG;;
      k) agent_key=$OPTARG;;
      o) organization=$OPTARG;;
      j) java_version=$OPTARG;;
     \?)
        echo "Error: Invalid option"
        exit;;
   esac
done

if [[ -z "$cassandra_restart" ]]; then
  cassandra_restart=false
fi 

# Check if options have been missed
if [[ -z "$cassandra_version" || -z "$cassandra_config_path" || -z "$cassandra_bin_path" || -z "$cassandra_user" || -z "$cassandra_group" || -z "$cassandra_native_transport_address" || -z "$cassandra_native_transport_port" || -z "$agent_key" || -z "$organization" || -z "$java_version" ]]; then
  echo "axon-agent-setup: error: the following options are required."
  echo ""
  Help
  exit 1
fi

# Check Valid Cassandra Version
if [[ $cassandra_version =~ ^[3-5]\.[0-9]+$ ]]; then
  cassandra_version="$(cut -d '.' -f 1,2 <<< $cassandra_version)"
else
  echo "Cassandra Version can only be numerical values. Format is Major.Minor versions e.g. 3.0 or 4.1"
  exit 1
fi

# Check Valid Config path
if ! test -d $cassandra_config_path; then
  echo "Cassandra config path $cassandra_config_path does not exist."
  exit 1
fi

# Check Valid Nodetool Binary path
if ! test -f $cassandra_bin_path/nodetool; then
  echo "Cassandra nodetool at location $cassandra_bin_path/nodetool is not accessible."
  exit 1
fi

# Check Valid Port number
regex_port="^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-6])$"
if [[ $cassandra_native_transport_port =~ $regex_port ]]; then
  cassandra_native_transport_port=$cassandra_native_transport_port
else
  echo "Cassandra Native Transport Port can only be numerical value between 1 and 65536."
  exit 1
fi

# Check java version that is installed 
cassandra_comparison_version="$(cut -d '.' -f 1 <<< $cassandra_version)"
if [[ $java_version -eq 8 ]] && [[ $cassandra_comparison_version -eq 4 ]]; then
  axon_install_agent="axon-cassandra$cassandra_version-agent-jdk8"
elif [[ $java_version -eq 11 ]] && [[ $cassandra_comparison_version -eq 5 ]]; then
  axon_install_agent="axon-cassandra$cassandra_version-agent-jdk11"
else
  axon_install_agent="axon-cassandra$cassandra_version-agent"
fi

############################################################
# Main program confirmation                                #
############################################################
echo ""
echo "####################################"
echo "You have set the following values : "
echo "####################################"
echo "Cassandra Version : $cassandra_version"
echo "Java Version : $java_version"
echo "Cassandra Config Path : $cassandra_config_path"
echo "Cassandra Bin Path : $cassandra_bin_path"
echo "Cassandra User : $cassandra_user"
echo "Cassandra Group : $cassandra_group"
echo "Restart Cassandra : $cassandra_restart"
echo "Cassandra Native Transport Address : $cassandra_native_transport_address"
echo "Cassandra Native Transport Port : $cassandra_native_transport_port"
echo "AxonOps Agent Key : $agent_key"
echo "AxonOps Organisation : $organization"

read -p "Do you want to proceed? (Yes/No) : " yn

case $yn in 
	[yY][eE][sS]|[yY] ) echo "Proceeding with configuration of AxonOps Agent.";;
	[nN][oO]|[nN] ) echo "Installation and configuration of AxonOps Agent aborted.";
		exit;;
	* ) echo "Invalid response";
    exit;;
esac

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

echo "# Check access to https://agents.axonops.cloud #############"

URL="https://agents.axonops.cloud/test.html"

response=$(curl -s $URL)
http_endpoint_reachable=$(tail -n1 <<< "$response")

if (echo "$http_endpoint_reachable" | grep -q -i "axonops agent test page"); then
  echo "AxonOps Agent URL is reachable" 
else
  echo "agents.axonops.cloud is unreachable please refer to the AxonOps docs at https://docs.axonops.com/get_started/agent_setup"
  exit 1
fi

echo "############################################################"
echo ""
echo "# Setup AxonOps APT or YUM repo and install AxonOps Agent ##"

## APT
if command -v apt-get >/dev/null; then
  echo "apt-get will be used"
  apt-get update
  apt-get install -y curl gnupg ca-certificates

  # Check if Debian or Ubuntu
  if [ -f "/etc/debian_version" ]; then
    curl -L https://packages.axonops.com/apt/repo-signing-key.gpg | gpg --yes --dearmor -o /usr/share/keyrings/axonops.gpg
    echo "deb [arch=arm64,amd64 signed-by=/usr/share/keyrings/axonops.gpg] https://packages.axonops.com/apt axonops-apt main" > /etc/apt/sources.list.d/axonops-apt.list
  else
    ubuntu_ver=$(lsb_release -sr | cut -d. -f1)
    if [[ $ubuntu_ver -ge 20 ]]; then
      echo "Ubuntu Version is same or newer than $ubuntu_ver.04"
      curl -L https://packages.axonops.com/apt/repo-signing-key.gpg | gpg --yes --dearmor -o /usr/share/keyrings/axonops.gpg
      echo "deb [arch=arm64,amd64 signed-by=/usr/share/keyrings/axonops.gpg] https://packages.axonops.com/apt axonops-apt main" > /etc/apt/sources.list.d/axonops-apt.list
    else
      echo "Ubuntu version is older than 20.04"
      curl https://packages.axonops.com/apt/repo-signing-key.gpg | apt-key add -
      echo "deb https://packages.axonops.com/apt axonops-apt main" > /etc/apt/sources.list.d/axonops-apt.list
    fi
  fi

  apt-get update
  apt-get install $axon_install_agent -y
### YUM
elif command -v yum >/dev/null; then
  echo "yum is used here"
  cat > /etc/yum.repos.d/axonops-yum.repo << EOL
[axonops-yum]
name=axonops-yum
baseurl=https://packages.axonops.com/yum/
enabled=1
repo_gpgcheck=0
gpgcheck=0
EOL
  # Install Axon Agent
  yum install $axon_install_agent -y

## DNF
elif command -v dnf > /dev/null; then
  echo "dnf is used here"
  cat > /etc/yum.repos.d/axonops-yum.repo << EOL
[axonops-yum]
name=axonops-yum
baseurl=https://packages.axonops.com/yum/
enabled=1
repo_gpgcheck=0
gpgcheck=0
EOL
  # Install Axon Agent
  dnf config-manager --add-repo /etc/yum.repos.d/axonops-yum.repo
  dnf install $axon_install_agent -y
else
  echo "Supported installation methods are APT or YUM, please check your Operating system is either Debian or RedHat."
  echo "Current Operating System Info :"
  echo "$(uname -a)"
  exit 1
fi

echo "############################################################"
echo ""
echo "# Configure Axon Agent #####################################"

systemctl stop axon-agent

cat > /etc/axonops/axon-agent.yml << EOL
axon-server:
  hosts: "agents.axonops.cloud"

axon-agent:
  key: $agent_key
  org: $organization

# Specify the NTP server IP addresses or hostnames configured for your Cassandra hosts
# if using Cassandra deployed in Kubernetes or if auto-detection fails.
# The port defaults to 123 if not specified.
# NTP:
#    hosts:
#        - "x.x.x.x:123"
# Optionally restrict which commands can be executed by axon-agent.
# If "true", only scripts placed in scripts_location can be executed by axon-agent.
# disable_command_exec: false
# If disable_command_exec is true then axon-agent is only allowed to execute scripts
# under this path
# scripts_location: /var/lib/axonops/scripts/
EOL

chmod 0644 /etc/axonops/axon-agent.yml

echo "############################################################"
echo ""
echo "# Cassandra JVM Updates ####################################"

echo "Adding axon-agent config to $cassandra_config_path/cassandra-env.sh"
jvm_opts="JVM_OPTS=\"\$JVM_OPTS -javaagent:/usr/share/axonops/axon-cassandra$cassandra_version-agent.jar=/etc/axonops/axon-agent.yml\""
if ! grep -R ".*axonops.axon-cassandra.*" "$cassandra_config_path/cassandra-env.sh"; then
  echo "$jvm_opts" >> $cassandra_config_path/cassandra-env.sh
else
  sed -i -r "s|.*JVM_OPTS=.*-javaagent:.*axonops.axon-cassandra[0-9.]+-agent.*|$jvm_opts|" $cassandra_config_path/cassandra-env.sh
fi

echo "############################################################"
echo ""
echo "# AxonOps Cassandra Group and User configs #################"

echo "Adding axon-agent user and group to Cassandra user and group"
usermod -aG $cassandra_group axonops
usermod -aG axonops $cassandra_user

echo "############################################################"
echo ""
echo "# Restart Cassandra ########################################"

stop_counter=0
start_counter=0
if $cassandra_restart; then # 
  echo "Stop Cassandra Service"
  systemctl stop cassandra
  while (systemctl is-active cassandra); do
    sleep 1
    stop_counter=$((stop_counter+1))
    echo "Waiting for Cassandra to gracefully shutdown"
    if [[ $stop_counter -ge 120 ]]; then
      echo "Cassandra Process did not stop after 120 seconds."
      echo "Please check the logs for any errors"
      exit 1
    fi
  done
  echo "Stopped Cassandra"
  echo "############################################################"
  echo "Start Cassandra Service"
  systemctl start cassandra
  while ! (echo > /dev/tcp/$cassandra_native_transport_address/$cassandra_native_transport_port) >/dev/null 2>&1; do
    echo "Cassandra still starting"
    sleep 1
    start_counter=$((start_counter+1))
    if [[ start_counter -ge 300 ]]; then
      echo "Cassandra Process did not start after 300 seconds."
      echo "Please check the logs for any errors"
      exit 1
    fi
  done

  echo "Cassandra Restarted, Please continue with the next node."
else
  echo "Cassandra needs to be restarted for the configuration changes to take effect."
fi

echo "############################################################"
echo ""
echo "# Start AxonOps Agent ######################################"

systemctl start axon-agent
echo "axon-agent started"
echo "Please go to https://console.axonops.cloud to start viewing you metrics"

echo "############################################################"