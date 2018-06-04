#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="absolute.conf"
ABS_DAEMON="/usr/local/bin/absoluted"
ABS_CLI="/usr/local/bin/absolute-cli"
ABS_REPO="https://github.com/absolute-community/absolute/releases/download/12.2.2/absolute_12.2.2_linux.tar.gz"
COIN_ZIP=$(echo $ABS_REPO | awk -F'/' '{print $NF}')
SENTINEL_REPO="https://github.com/absolute-community/sentinel.git "
DEFAULTABSPORT=18888
DEFAULTABSUSER="absuser"
NODEIP=$(curl -s4 icanhazip.com)


RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'


function get_ip() {
  declare -a NODE_IPS
  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
      echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $ABS_DAEMON)" ] || [ -e "$ABS_DAEMOM" ] ; then
  echo -e "${GREEN}\c"
  read -e -p "Absolute is already installed. Do you want to add another MN? [Y/N]" NEW_ABS
  echo -e "{NC}"
  clear
else
  NEW_ABS="new"
fi
}

function prepare_system() {

echo -e "Prepare the system to install Absolute master node."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libevent-dev nano jq htop git pwgen libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget pwgen curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
libminiupnpc-dev libgmp3-dev ufw python-virtualenv unzip >/dev/null 2>&1
clear
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake nano jq htop git pwgen curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw fail2ban python-virtualenv unzip"
 exit 1
fi

clear
echo -e "Checking if swap space is needed."
PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
SWAP=$(free -g|awk '/^Swap:/{print $2}')
if [ "$PHYMEM" -lt "2" ] && [ -n "$SWAP" ]
  then
    echo -e "${GREEN}Server is running with less than 2G of RAM without SWAP, creating 2G swap file.${NC}"
    SWAPFILE=$(mktemp)
    dd if=/dev/zero of=$SWAPFILE bs=1024 count=2M
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon -a $SWAPFILE
else
  echo -e "${GREEN}Server running with at least 2G of RAM, no swap needed.${NC}"
fi
clear
}

function compile_node() {
  echo -e "Download binaries. This may take some time. Press a key to continue."
  cd $TMP_FOLDER >/dev/null 2>&1
  wget -q $ABS_REPO >/dev/null 2>&1
  tar xvzf $COIN_ZIP --strip 1 >/dev/null 2>&1
  compile_error AbsoluteCoin
  cp abs* /usr/local/bin
  chmod +x /usr/local/bin/abs*
  cd - 
  rm -rf $TMP_FOLDER
  clear
}

function enable_firewall() {
  echo -e "Installing and setting up firewall to allow ingress on port ${GREEN}$ABSPORT${NC}"
  ufw allow $ABSPORT/tcp comment "ABS MN port" >/dev/null
  ufw allow $[ABSPORT+1]/tcp comment "ABS RPC port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}

function configure_systemd() {
  cat << EOF > /etc/systemd/system/$ABSUSER.service
[Unit]
Description=ABS service
After=network.target

[Service]
User=$ABSUSER
Group=$ABSUSER

Type=forking
PIDFile=$ABSFOLDER/$ABSUSER.pid

ExecStart=$ABS_DAEMON -daemon -pid=$ABSFOLDER/$ABSUSER.pid -conf=$ABSFOLDER/$CONFIG_FILE -datadir=$ABSFOLDER
ExecStop=-$ABS_CLI -conf=$ABSFOLDER/$CONFIG_FILE -datadir=$ABSFOLDER stop

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=2s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $ABSUSER.service
  systemctl enable $ABSUSER.service

  if [[ -z "$(ps axo user:15,cmd:100 | egrep ^$ABSUSER | grep $ABS_DAEMON)" ]]; then
    echo -e "${RED}ABS is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $ABSUSER.service"
    echo -e "systemctl status $ABSUSER.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}

function ask_port() {
read -p "Absolute Port: " -i $DEFAULTABSPORT -e ABSPORT
: ${ABSPORT:=$DEFAULTABSPORT}
}

function ask_user() {
  read -p "Absolute user: " -i $DEFAULTABSUSER -e ABSUSER
  : ${ABSUSER:=$DEFAULTABSUSER}

  if [ -z "$(getent passwd $ABSUSER)" ]; then
    USERPASS=$(pwgen -s 12 1)
    useradd -m $ABSUSER
    echo "$ABSUSER:$USERPASS" | chpasswd

    ABSHOME=$(sudo -H -u $ABSUSER bash -c 'echo $HOME')
    DEFAULTABSFOLDER="$ABSHOME/.absolutecore"
    read -p "Configuration folder: " -i $DEFAULTABSFOLDER -e ABSFOLDER
    : ${ABSFOLDER:=$DEFAULTABSFOLDER}
    mkdir -p $ABSFOLDER
    chown -R $ABSUSER: $ABSFOLDER >/dev/null
  else
    clear
    echo -e "${RED}User exits. Please enter another username: ${NC}"
    ask_user
  fi
}

function check_port() {
  declare -a PORTS
  PORTS=($(netstat -tnlp | grep $NODEIP | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $ABSPORT ]] || [[ ${PORTS[@]} =~ $[ABSPORT-1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function create_config() {
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $ABSFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
rpcport=$[ABSPORT+1]
listen=1
server=1
#bind=$NODEIP
daemon=1
port=$ABSPORT
EOF
}

function create_key() {
  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -e ABSKEY
  if [[ -z "$ABSKEY" ]]; then
    su $ABSUSER -c "$ABS_DAEMON -conf=$ABSFOLDER/$CONFIG_FILE -datadir=$ABSFOLDER"
    sleep 30
    if [ -z "$(ps axo user:15,cmd:100 | egrep ^$ABSUSER | grep $ABS_DAEMON)" ]; then
     echo -e "${RED}Absolute server couldn't start. Check /var/log/syslog for errors.{$NC}"
     exit 1
    fi
    ABSKEY=$(su $ABSUSER -c "$ABS_CLI -conf=$ABSFOLDER/$CONFIG_FILE -datadir=$ABSFOLDER masternode genkey")
    if [ "$?" -gt "0" ];
      then
       echo -e "${RED}Wallet not fully loaded, need to wait a bit more time. ${NC}"
       sleep 30
       ABSKEY=$(su $ABSUSER -c "$ABS_CLI -conf=$ABSFOLDER/$CONFIG_FILE -datadir=$ABSFOLDER masternode genkey")
    fi
    su $ABSUSER -c "$ABS_CLI -conf=$ABSFOLDER/$CONFIG_FILE -datadir=$ABSFOLDER stop"
  fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $ABSFOLDER/$CONFIG_FILE
  cat << EOF >> $ABSFOLDER/$CONFIG_FILE
maxconnections=256
externalip=$NODEIP
masternode=1
masternodeaddr=$NODEIP:$ABSPORT
masternodeprivkey=$ABSKEY
EOF
  chown -R $ABSUSER: $ABSFOLDER >/dev/null
}


function install_sentinel() {
  SENTINELPORT=$[10001+$ABSPORT]
  echo -e "${GREEN}Install sentinel.${NC}"
  apt-get install virtualenv >/dev/null 2>&1
  git clone $SENTINEL_REPO $ABSHOME/sentinel >/dev/null 2>&1
  cd $ABSHOME/sentinel
  virtualenv ./venv >/dev/null 2>&1  
  ./venv/bin/pip install -r requirements.txt >/dev/null 2>&1
  cd $ABSHOME
  sed -i "s/28889/$SENTINELPORT/g" $ABSHOME/sentinel/test/unit/test_absolute_config.py
  echo  "* * * * * cd $ABSHOME/sentinel && ./venv/bin/python bin/sentinel.py >> ~/sentinel.log 2>&1" > $ABSHOME/abs_cron
  chown -R $ABSUSER: $ABSHOME/sentinel >/dev/null 2>&1
  chown $ABSUSER: $ABSHOME/abs_cron >/dev/null 2>&1
  crontab -u $ABSUSER $ABSHOME/abs_cron >/dev/null 2>&1
  rm abs_cron >/dev/null 2>&1
}

function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "Absolute Masternode is up and running as user ${GREEN}$ABSUSER${NC} and it is listening on port ${GREEN}$ABSPORT${NC}."
 echo -e "${GREEN}$ABSUSER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$ABSFOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $ABSUSER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $ABSUSER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODEIP:$ABSPORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$ABSKEY${NC}"
 echo -e "Please check Absolute is running with the following command: ${GREEN}systemctl status $ABSUSER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
  get_ip
  ask_user
  check_port
  create_config
  create_key
  update_config
  enable_firewall
  configure_systemd
  install_sentinel
  important_information
}


##### Main #####
clear

checks
if [[ ("$NEW_ABS" == "y" || "$NEW_ABS" == "Y") ]]; then
  setup_node
  exit 0
elif [[ "$NEW_ABS" == "new" ]]; then
  prepare_system
  compile_node
  setup_node
else
  echo -e "${GREEN}Absolute already running.${NC}"
  exit 0
fi

