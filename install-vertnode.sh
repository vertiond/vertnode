#!/bin/bash
#
# TESTING IN PROGRESS
#
# An automated script to assist with installing Vertcoin full node(s)
# -------------------------------------------------------------------
# AUTHORS:
# jochemin   | Twitter: @jochemin | BTC Donations --> 3FM6FypcrSVhdHh7cpVQMrhPXPZ6zcXeYU
# Sam Sepiol | Email: ecorp-sam.sepiol@protonmail.com 
# SPECIAL THANKS:
# Thanks @b17z, this fork would not have happened without you. Thanks
# for your help and inspiration. 
#
# Dedicated to the Vertcoin community. 
# -------------------------------------------------------------------
# Functions:
#           color functions
#               greentext
#               yellowtext
#               redtext
#           hd_detect           | detect USB flash drive, format
#           hd_config           | configure USB flash drive
#           swap_config         | configure swap file to reside on formatted USB flash drive
#           user_input          | take user input for rpcuser and rpcpass
#           network_addr        | grab the LAN network addresses of the host running this script
#           secure              | modify iptables to limit connections for security purposes
#           update_rasp         | update the system
#           install_berkeley    | install berkeley database 4.8 for wallet functionality
#           install_vertcoind   | clone, build and install vertcoin core daemon
#           config_vertcoin     | create ~/.vertcoin/vertcoin.conf to configure vertcoind
#           install_depends     | install the required dependencies to run this script
#           grab_vtc_release    | grab the latest vertcoind release from github
#           wait_for_continue   | function for classic "Press spacebar to continue..." 
#           grab_vtc_release    | grab the latest vertcoind release from github
#           grab_bootstrap      | grab the latest bootstrap.dat from alwayshashing
#           compile_or_compiled | prompt the user for input; would you like to build vertcoin core 
#           load_blockchain     | prompt the user for input; would you like to sideload the blocks folder and verthash.dat
#           prompt_p2pool       | function to prompt user with option to install p2pool
#           install_p2pool      | function to download and configure p2pool
#           userinput_lit       | function to prompt user with option to install lit and lit-af
#           install_lit         | function to download and install golang, lit and lit-af
#           user_intro          | introduction to installation script, any key to continue
#           installation_report | report back key and contextual information
#           wait_for_continue   | function for classic "Press spacebar to continue..." 
#           config_crontab      | function to configure crontab to start 
# -------------------------------------------------------------------

# hinder root from running script
if [[ $EUID -eq 0 ]]; then
  echo "Please do not run this script as root." 1>&2
  exit 1
fi
# clear the screen to begin
clear
# install depends for detection; check for lshw, install if not
if [ $(dpkg-query -W -f='${Status}' lshw 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "Installing required dependencies to run install-vertnode..."    
    sudo apt install lshw -y
fi
# install depends for detection; check for gawk, install if not
if [ $(dpkg-query -W -f='${Status}' gawk 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "Installing required dependencies to run install-vertnode..."    
    sudo apt install gawk -y
fi
# install depends for detection; check for git, install if not
if [ $(dpkg-query -W -f='${Status}' git 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "Installing required dependencies to run install-vertnode..."    
    sudo apt install git -y
fi
# fail on error; debug all lines
set -eu -o pipefail
# colors for console output
TEXT_RESET='\e[0m'
TEXT_YELLOW='\e[0;33m'
TEXT_RED='\e[1;31m'
TEXT_GREEN='\e[0;32m'
# global script variables
user=$(logname)
userhome='/home/'$user
FOLD1='/dev/'
PUBLICIP="$(curl -s ipinfo.io/ip)"
KERNEL="$(uname -a | awk '{print $2}')"
# grab the first column of system name
SYSTEM="$(sudo lshw -short | grep system | awk -F'[: ]+' '{print $3" "$4" "$5" "$6" "$7" "$8" "$9" "$10" "$11}' | awk '{print}')"
# grab the default gateway ip address
GATEWAY="$(ip r | grep "via " | awk -F'[: ]+' '{print $3}')"
# grab the release name of operating system
RELEASE="$(cat /etc/*-release | gawk -F= '/^NAME/{print $2}' | tr -d '"')"
#'
RAM="$(cat /proc/meminfo | grep MemTotal | awk -F'[: ]+' '{print $2}')"
RAM_MIN='1910000'
ARCH="$(dpkg --print-architecture)"
P2P=''
INSTALLP2POOL=''
BUILDVERTCOIN=''
LOADBLOCKMETHOD=''
MAXUPLOAD=''
# find the active interface
while true; do
    if [[ $SYSTEM = "Rockchip"* ]]; then
        sudo apt install facter -y
        # grab only the first row of data, user may want wifi + lan
        INTERFACE="$(sudo facter 2>/dev/null | grep ipaddress_et | awk '{print $1}' | sed 's/.*_//' | awk 'NR==1{print $1}')"
        break
    else
        # grab only the first row of data, user may want wifi + lan
        INTERFACE="$(ip -o link show | awk '{print $2,$9}' | grep UP | awk '{print $1}' | sed 's/:$//' | awk 'NR==1{print $1}')"
        break
    fi
done
# check the active interface for its ip address
while true; do
    # check if system is a raspberry pi, grep for only inet if true, print the 2nd column
    if [[ $SYSTEM = "Raspberry"* ]]; then
        # grab ip address for raspberry pi    
        LANIP="$(ifconfig $INTERFACE | grep "inet " | awk -F'[: ]+' '{print $3}' | awk 'NR==1{print $1}')"
        break 
    elif [[ $SYSTEM = "Rockchip"* ]]; then
        # grab ip address for rock64 
        LANIP="$(sudo facter 2>/dev/null | grep ipaddress_et | awk '{print $3}')"
        break
    else
            if [[ $KERNEL = "orangepione" ]]; then  
                # grab ip address for orange pi one
                LANIP="$(sudo ifconfig $INTERFACE | grep "inet " | awk -F'[: ]+' '{print $3}' | awk 'NR==1{print $1}')"
            else
                # grap ip address for ubuntu
                LANIP="$(sudo ifconfig $INTERFACE | grep "inet addr" | awk -F'[: ]+' '{print $4}')"
            fi
        # do nothing        
        :
        break
    fi
done

# -----------------------------------

# network_addr | grab the LAN network address range of the host running this script
function network_addr {
    network_address=$(ip -o -f inet addr show | awk '/scope global/{sub(/[^.]+\//,"0/",$4);print $4}' | awk 'NR==1{print $1}')
}

# wait_for_continue | function for classic "Press spacebar to continue..." 
function wait_for_continue {
    echo 
    echo "DO NOT CONTINUE UNTIL BLOCKS AND VERTHASH.DAT HAVE BEEN"
    echo "COMPLETELY COPIED OVER TO $userhome/.vertcoin/"
    echo
    read -n 1 -s -r -p "Press any key to continue..."
    echo
}

# color functions
function greentext(){
    echo -e -n "\e[0;32m$1"
    echo -e -n '\033[0m\n'
}
function yellowtext(){
    echo -e -n "\e[0;33m$1"
    echo -e -n '\033[0m\n'
}
function redtext(){
    echo -e -n "\e[1;31m$1"
    echo -e -n '\033[0m\n'
}

# user_intro | introduction to installation script, any key to continue
function user_intro {
    greentext 'Welcome to the Vertnode installation script!'
    echo
    greentext 'This script will install the Vertcoin software and allow for'
    greentext 'easy configuration of a Vertcoin full node. Additionally the'
    greentext 'script provides an optional installation and configuration of'
    greentext 'p2pool-vtc.'
    echo 
    echo "To make this node a full node, please visit $GATEWAY with the"
    echo "URL bar of your web browser. Login to your router and continue"
    echo "to the port forwarding section and port forward..."
    echo "$LANIP TCP/UDP 5889"
    echo
    yellowtext 'What is a full node? It is a Vertcoin server that contains the'
    yellowtext 'full blockchain and propagates transactions throughout the Vertcoin'
    yellowtext 'network via peers). Playing its part to keep the Vertcoin peer-to-peer'
    yellowtext 'network healthy and strong.'
    echo
    read -n 1 -s -r -p "Press any key to continue..."
}

# user_input | take user input for rpcuser and rpcpass
function user_input {
    # check for USB flash drive
    while true; do
        clear
        echo -e "$TEXT_GREEN"
        read -p "Is the USB flash drive connected? It will be formatted. (y/n) " yn
        case $yn in
            [Yy]* ) hd_detect; break;;  # if we have hd_config value we can configure it
            [Nn]* ) echo "Please connect USB flash drive and retry."; exit;;
            * ) echo "Do you wish to continue? (y/n) ";;
        esac
    done
    clear
    echo -e "$TEXT_GREEN"
    echo 'Vertcoin requires both an rpcuser & rpcpassword, enter your preferred values: '
    read -p 'Enter RPC user: ' rpcuser
    read -s -p 'Enter RPC password: ' rpcpass
    clear    
    while true; do
        echo -e "$TEXT_GREEN"
        echo "What would you like the maximum amount of data (in MegaBytes) "
        echo "that you would like to allow your Vertcoin node to upload daily? "
        echo
        echo "Examples:"
        echo "          1024 = 1GB"
        echo "          2048 = 2GB"
        echo "          3072 = 3GB"
        echo "          4096 = 4GB"
        echo "          5120 = 5GB" 
        echo 
        read -p 'maxuploadtarget=' MAXUPLOAD
        # little bit of macgyvering here. this if statement uses -eq for something 
        # other then it was intended. it checks for an integer, if it doesnt 
        # find an one then it returns an error which is passed to /dev/null 
        # and a value of false.
        if [ $MAXUPLOAD -eq $MAXUPLOAD 2>/dev/null ]
            then
                # if MAXUPLOAD is an integer break from loop and continue
                break
            else
                echo "$MAXUPLOAD isn't a number. Please try again."
        fi
    done
}

# compile_or_compiled | prompt the user for input; would you like to build vertcoin core 
#                     | from source or would you like to grab the latest release binary?
function compile_or_compiled {
    # if the system name contains RaspberryPiZero then compile from source
    # to avoid segmentation fault errors   
    while true; do
        if [[ $SYSTEM = "Rockchip"* ]]; then
            echo "**************************************************************************"           
            echo "HARDWARE = $SYSTEM"
            echo "No precompiled releases are made available for $SYSTEM $ARCH."
            echo
            echo "This script will build Vertcoin Core from source..."
            echo "NOTE: These operations will utilize the CPU @ 100% for some time."
            echo "**************************************************************************"
            sleep 15
            BUILDVERTCOIN="install_vertcoind"
            break
        fi
            # prompt user if they would like to build from source
        read -p "Would you like to build Vertcoin from source? (y/n) " yn
        case $yn in 
            # if user says yes, call install_vertcoind to compile source
            [Yy]*   )   BUILDVERTCOIN="install_vertcoind"; break;;
            # if user says no, grab latest vtc release and break from loop            
            [Nn]*   )   BUILDVERTCOIN="grab_vtc_release"; break;;
        esac
    done
}

# prompt_p2pool | function to prompt user with option to install p2pool
function prompt_p2pool {
    while true; do
        echo
        read -p "Would you like install p2pool-vtc? (y/n) " yn
        case $yn$P2P in 
            # if user says yes, call install_p2pool 
            [Yy]*   )   INSTALLP2POOL="install_p2pool"; break;;
            # if user says no, break from loop            
            [Nn]*   )   INSTALLP2POOL=""; break;;
        esac
    done
}

# load_blockchain | prompt the user for input; would you like to sideload the
#                 | the vertcoin blockchain or grab the latest bootstrap.dat
function load_blockchain {
    # prompt user with menu selection
    echo
    PS3="Are you going to sideload the blocks folder and verthash.dat @ $LANIP:22 ? "
    options=("Yes, I will sideload the blocks folder and verthash.dat." "No, sync on it's own.")
    select opt in "${options[@]}"
    do
        case $opt in
            "Yes, I will sideload the blocks folder and verthash.dat.")
                LOADBLOCKMETHOD="wait_for_continue"         
                break       
                ;;
            "No, sync on it's own.")
                LOADBLOCKMETHOD=""
                break         
                ;;
            * ) echo "Invalid option, please try again";;
        esac
    done
}

# init_script
function init_script {
    echo    
    greentext 'Initializing Vertnode installation script...' 
    echo
    yellowtext '****************************************************************'
    if [[ $BUILDVERTCOIN = "install_vertcoind" ]]; then
        yellowtext 'Vertcoin Installation      | Build from source'
    else
        yellowtext 'Vertcoin Installation      | Latest vertcoin-core release'    
    fi  
    if [[ $INSTALLP2POOL = "install_p2pool" ]]; then
        yellowtext 'P2Pool-vtc Installation    | True'
    else
        yellowtext 'P2Pool-vtc Installation    | False'    
    fi  
    if [[ $LOADBLOCKMETHOD = "wait_for_continue" ]]; then
        yellowtext 'Blockchain Loading Method  | Sideload the blocks folder and verthash.dat'
    else
        yellowtext 'Blockchain Loading Method  | Sync on its own'  
    fi  
    yellowtext '****************************************************************'
    sleep 10
}

# update_rasp | update the system
function update_rasp {
    yellowtext 'Initializing system update...'
    sudo apt update
    sudo apt upgrade -y
    sudo apt autoremove -y
    greentext 'Successfully updated system!'
    echo
}

# install_depends | install the required dependencies to run this script
function install_depends {
    yellowtext 'Installing package dependencies...'
    sudo apt install -y build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils python3 libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev git fail2ban dphys-swapfile unzip python python2.7-dev libgmp-dev
    greentext 'Successfully installed required dependencies!'
    echo
}

# secure | modify iptables to limit connections for security purposes
function secure {
    yellowtext 'Configuring firewall...'
    # install the dependancy 
    sudo apt install ufw -y
    # call the function network_addr    
    network_addr
    # configure ufw firewall   
    echo
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow from $network_address to any port 22 comment 'allow SSH from local LAN'
    sudo ufw allow 5889 comment 'allow vertcoin core'
    sudo ufw --force enable
    sudo systemctl enable ufw
    sudo ufw status
    echo 
    greentext 'Successfully configured firewall!'
    echo 
}

# hd_detect | USB flash drive detect; prompt for formatting
function hd_detect {
    # grep the output of lsblk -dlnb for the sda device
    # pass it to awk and print the fourth column of that row
    # that value = the size of the sda device
    usbsize=$(lsblk -dlnb | grep sda | awk '{print $4}')
    # list block devices that are greater than or equal to 15GB, cut the first three characters
    # make sure the microSD card that holds raspbian is 8GB or smaller to ensure find_drive picks 
    # the correct block device.
    find_drive="$(lsblk -dlnb | awk '{if($3 == 1){print}}' | awk '{print $1}')"
    drive=$FOLD1$find_drive 
    drive_size="$(df -h "$drive" | sed 1d |  awk '{print $2}')"
    while true; do
        echo -e "$TEXT_RED"
        read -p "$drive_size $drive will be formatted. Do you wish to continue? (y/n) " yn
        case $yn in
            [Yy]* ) DRIVE_CONF=true; break;;
            [Nn]* ) echo "This script needs to format the entire flash drive.";
                    echo -e "$TEXT_RESET"; exit;;
            * ) echo "Do you wish to continue? (y/n) ";;
        esac
        echo -e "$TEXT_RESET"
    done
}

# hd_config | configure USB flash drive
function hd_config {
    drive=$drive"1"
        if mount | grep "$drive" > /dev/null; then
            sudo umount -l "$drive" > /dev/null
        fi
    yellowtext 'Formatting USB flash drive...'
    # format usb disk as ext4 filesystem    
    sudo mkfs.ext4 -F "$drive" -L storage
    greentext 'Successfully formatted flash drive!'
    # locally declare UUID as the value given by blkid
    UUID="$(sudo blkid -o value -s UUID "$drive")"
    echo
    yellowtext 'Creating Vertcoin data folder...'
    VTCDIR='/home/'$user'/.vertcoin'
    mkdir -p "$VTCDIR"
    yellowtext 'Modifying fstab configuration...'
    echo    
    sudo sed -i".bak" "/$UUID/d" /etc/fstab    
    sudo sh -c "echo 'UUID=$UUID  $VTCDIR  ext4  defaults,noatime  0    0' >> /etc/fstab"
        if mount | grep "$drive" > /dev/null; then
            :
        else
            sudo mount -a
        fi
    sudo chmod 777 $VTCDIR
    greentext 'Successfully configured USB flash drive!'
    echo
}

# swap_config | configure swap file to reside on formatted flash drive
function swap_config {
    # !! notify user the ability to begin sideloading blockchain
    yellowtext '********************************************************************'
    greentext ' NOTICE: Sideloading is now available'    
    echo
    echo " If you intend on sideloading the blocks folder and verthash.dat please use an " 
    echo " SFTP client such as WinSCP or FileZilla to copy the BLOCKS"
    echo " folder and verthash.dat to /home/$user/.vertcoin/"
    yellowtext '--------------------------------------------------------------------'
    greentext ' HOW TO CONNECT: '
    echo
    echo " Using WinSCP or FileZilla please connect to... "    
    echo 
    echo " IP Address: $LANIP"    
    echo " Port: 22 "
    echo " Username: $user "
    echo " Password: (pi default pass: raspberry)" 
    echo "           (rock64 default pass: rock64)"    
    yellowtext '********************************************************************'
    echo
    # continue and configure swap    
    yellowtext 'Configuring swap file to reside on USB flash drive...'
    echo
	sudo sed -i".bak" "/CONF_SWAPFILE/d" /etc/dphys-swapfile
	sudo sed -i".bak" "/CONF_SWAPSIZE/d" /etc/dphys-swapfile
	sudo sh -c "echo 'CONF_SWAPFILE=/home/$user/.vertcoin/swap' >> /etc/dphys-swapfile"
	sudo sh -c "echo 'CONF_SWAPSIZE=2048' >> /etc/dphys-swapfile"
    echo    
    greentext 'Successfully configured swap space!'
    echo
}

# install_berkeley | install berkeley database 4.8 for wallet functionality
function install_berkeley {
    yellowtext 'Installing Berkeley (4.8) database...'
    mkdir -p "$userhome"/bin
    cd "$userhome"/bin
    wget http://download.oracle.com/berkeley-db/db-4.8.30.NC.tar.gz
    tar -xzvf db-4.8.30.NC.tar.gz
    cd db-4.8.30.NC/build_unix/
    # check if system is rock64, specify build type if true
    if [[ $SYSTEM = "Rockchip"* ]]; then
        ../dist/configure --enable-cxx --build=aarch64-unknown-linux-gnu
    else
        ../dist/configure --enable-cxx
    fi
    make
    sudo make install
    # set the current environment berkeley db location
    export LD_LIBRARY_PATH="/usr/local/BerkeleyDB.4.8/lib/"
    # echo the same location into .bashrc for persistence
    echo 'export LD_LIBRARY_PATH=/usr/local/BerkeleyDB.4.8/lib/' >> /home/"$user"/.bashrc
    greentext 'Successfully installed Berkeley (4.8) database!'
    echo
}

# userinput_vertcoin | begin configuration, building and installation of vertcoin
function userinput_vertcoin {
    # check for user response to compile from source
    if [[ $BUILDVERTCOIN = "install_vertcoind" ]]; then
        # if user selected to compile vertcoin from source, then compile
        install_vertcoind
    else
        # grab latest vtc release
        grab_vtc_release   
    fi   
}

# install_vertcoind | clone, build and install vertcoin core daemon
function install_vertcoind {
    install_berkeley      
    # continue on compiling vertcoin from source
    yellowtext 'Installing Vertcoin Core...'
    rm -fR "$userhome"/bin/vertcoin-core
    cd "$userhome"/bin
    git clone https://github.com/vertcoin-project/vertcoin-core
    while true; do        
       if [[ $SYSTEM = "Rockchip"* ]]; then
                cd "$userhome"/bin/vertcoin-core/
                ./autogen.sh        
                ./configure CPPFLAGS="-I/usr/local/BerkeleyDB.4.8/include -O2" LDFLAGS="-L/usr/local/BerkeleyDB.4.8/lib" --enable-upnp-default --build=aarch64-unknown-linux-gnu             
                break
       else
                cd "$userhome"/bin/vertcoin-core/
                ./autogen.sh        
                ./configure CPPFLAGS="-I/usr/local/BerkeleyDB.4.8/include -O2" LDFLAGS="-L/usr/local/BerkeleyDB.4.8/lib" --enable-upnp-default --disable-tests --disable-bench CXXFLAGS="--param ggc-min-expand=1 --param ggc-min-heapsize=32768" 
                break
        fi
    done
    cd "$userhome"/bin/vertcoin-core/
    make
    sudo make install
    greentext 'Successfully installed Vertcoin Core!'
    echo
}

# grab_vtc_release | grab the latest vertcoind release from github
function grab_vtc_release {
    if [[ $RELEASE = "Ubuntu" ]]; then
        sudo add-apt-repository ppa:bitcoin/bitcoin -y
        sudo apt update 
        sudo apt install libdb4.8-dev libdb4.8++-dev -y  
    fi
    # grab the latest version number; store in variable $VERSION
    export VERSION=$(curl -s "https://github.com/vertcoin-project/vertcoin-core/releases/latest" | grep -o 'tag/[v.0-9]*' | awk -F/ '{print $2}')
    # grab the latest version release; deviation in release naming scheme will break this
    # release naming scheme needs to be: 'vertcoind-v(release#)-linux-armhf.zip' to work
    wget https://github.com/vertcoin-project/vertcoin-core/releases/download/$VERSION/vertcoind-v$VERSION-arm-linux-gnueabihf.zip
    unzip vertcoind-v$VERSION-arm-linux-gnueabihf.zip
    # clean up    
    rm vertcoind-v$VERSION-arm-linux-gnueabihf.zip
    # move vertcoin binaries to /usr/bin/ 
    sudo mv vertcoind vertcoin-tx vertcoin-cli vertcoin-wallet /usr/bin/
}

# config_crontab | function to configure crontab to start 
function config_crontab {
    VTCRON=$({ crontab -l -u $user 2>/dev/null; echo '@reboot vertcoind -daemon'; } | crontab -u $user - )
    echo    
    yellowtext 'Configuring Crontab...'
    yellowtext '** vertcoind  | start on reboot'
    $VTCRON
    echo
    greentext 'Successfully configured Crontab!'
}

# config_vertcoin | create ~/.vertcoin/vertcoin.conf to configure vertcoind
function config_vertcoin {
    # echo values into a file named vertcoin.conf
    echo "server=1" >> /home/"$user"/.vertcoin/vertcoin.conf
    echo "rpcuser=$rpcuser" >> /home/"$user"/.vertcoin/vertcoin.conf
    echo "rpcpassword=$rpcpass" >> /home/"$user"/.vertcoin/vertcoin.conf
    echo "rpcport=5888" >> /home/"$user"/.vertcoin/vertcoin.conf
    echo 'dbcache=100' >> /home/"$user"/.vertcoin/vertcoin.conf
    echo 'maxconnections=30' >> /home/"$user"/.vertcoin/vertcoin.conf
    echo "maxuploadtarget=$MAXUPLOAD" >> /home/"$user"/.vertcoin/vertcoin.conf
    # configure permissions for user access
    cd "$userhome"/.vertcoin/
}

# userinput_p2pool | configure p2pool based on user input
function userinput_p2pool {
    while true; do
            # check for user response to install p2pool
        if [[ $INSTALLP2POOL = "install_p2pool" ]]; then
            # if user selected to install p2pool, then install it
            install_p2pool
            break
        else
            # else do nothing and break from loop
            :        
            break
        fi
    done 
}

# install_p2pool | function to download and configure p2pool
function install_p2pool {
    echo
    yellowtext 'Installing p2pool-vtc...'
    # install dependencies for p2pool-vtc
    sudo apt install python-rrdtool python-pygame python-scipy python-twisted python-twisted-web python-pil python-pip libffi-dev at -y
    # grab latest p2pool-vtc release
    cd "$userhome"/
	wget "https://github.com/vertcoin-project/p2pool-vtc/archive/v3.0.0.zip"
	unzip v3.0.0.zip
	rm v3.0.0.zip
	mv p2pool-vtc-3.0.0 p2pool-vtc
    cd "$userhome"/p2pool-vtc
    sudo python setup.py install
    # download alternative web frontend and install
    echo
    yellowtext 'Installing alternate web frontend for p2pool-vtc...'
    echo
    cd "$userhome"/
    git clone https://github.com/hardcpp/P2PoolExtendedFrontEnd
    cd "$userhome"/P2PoolExtendedFrontEnd/
    mv * /home/$user/p2pool-vtc/web-static/
    cd "$userhome"/
    # clean up
    sudo rm -r P2PoolExtendedFrontEnd/
    echo
    greentext 'Successfully installed alternate web frontend for p2pool-vtc!'
    # grab the LAN IP range and store it in variable network_address    
    network_address=$(ip -o -f inet addr show | awk '/scope global/{sub(/[^.]+\//,"0/",$4);print $4}')
    # open p2pool port
    sudo ufw allow 9171 comment 'allow -- mining port'
    sudo ufw allow 9346 comment 'allow -- p2p port'
    sudo ufw --force enable
    sudo ufw status
    # echo our values into a file named start-p2pool.sh
    echo "#!/bin/bash" >> /home/"$user"/start-p2pool.sh
    echo "cd p2pool-vtc" >> /home/"$user"/start-p2pool.sh
    echo    
    yellowtext 'Configuring Crontab...'    
    yellowtext '** p2pool-vtc | start on reboot'    
    # define p2poolcron variable and store command to echo new cronjob into crontab    
    P2POOLCRON=$({ crontab -l -u $user 2>/dev/null; echo "@reboot sleep 120; nohup sh /home/$user/start-p2pool.sh"; } | crontab -u $user - ) 
    # echo cronjob value into crontab
    $P2POOLCRON
}

function initiate_p2pool {
    echo
    getnewaddress=$(vertcoin-cli getnewaddress)
    echo "python run_p2pool.py --net vertcoin -a $getnewaddress --max-conns 8 --outgoing-conns 4" >> /home/"$user"/start-p2pool.sh
    # permission the script for execution
    cd "$userhome"/
    chmod +x start-p2pool.sh
    echo
    greentext 'Successfully configured p2pool-vtc!'
    yellowtext 'Starting p2pool-vtc...'
    sudo ln -s /home/"$user"/.vertcoin/verthash.dat /home/"$user"/p2pool-vtc
    cd "$userhome"/
    echo "./start-p2pool.sh" | at now    
}

# initiate_blockchain | take user response from load_blockchain and execute
function initiate_blockchain {
    if [[ $LOADBLOCKMETHOD = "wait_for_continue" ]]; then
        # if user selected to install p2pool, then install it
        wait_for_continue
        echo
        greentext 'Starting Vertcoin Core...'
        echo
        if [[ $BUILDVERTCOIN="install_vertcoind" ]]; then
            # if vertcoin was built from source set berkeleydb path 
            # env variable was exported to .bashrc but not active until new terminal session
            export LD_LIBRARY_PATH="/usr/local/BerkeleyDB.4.8/lib/"
            vertcoind -daemon
            echo
            greentext 'Waiting two minutes for Vertcoin Core to start...' 
            sleep 120 
            initiate_p2pool
        else
            # just launch vertcoin because vertcoin was compiled for us
            vertcoind -daemon 
            echo
            greentext 'Waiting two minutes for Vertcoin Core to start...'
            sleep 120 
            initiate_p2pool
        fi         
    else
        # else just sync vertcoin on its own
        echo
        # wait two minutes to ensure vertcoin core is alive before moving on
        greentext 'Starting Vertcoin Core...'
        echo
        greentext 'Waiting forty minutes for Vertcoin Core to start and verthash.dat to generate...' 
        echo
        if [[ $BUILDVERTCOIN="install_vertcoind" ]]; then
            # if vertcoin was built from source set berkeleydb path 
            # env variable was exported to .bashrc but not active until new terminal session
            export LD_LIBRARY_PATH="/usr/local/BerkeleyDB.4.8/lib/"
            vertcoind -daemon        
            sleep 2400
            initiate_p2pool
        else
            # just launch vertcoin because vertcoin was compiled for us
            vertcoind -daemon 
            sleep 2400 
            initiate_p2pool
        fi       
    fi 
}

# post installation_report | report back key and contextual information
function installation_report {
    echo
    echo "VERTNODE INSTALLATION SCRIPT COMPLETE"
    echo "-------------------------------------"
    echo "Public IP Address: $PUBLICIP"
    echo "Local IP Address: $LANIP"
    echo "Default Gateway: $GATEWAY"
    echo "Vertcoin Data: $userhome/.vertcoin/"
    echo    
    echo "p2pool-vtc -----------"    
    echo "$LANIP:9171"

    echo "-------------------------------------"
    echo
    echo "To make this node a full node, please visit $GATEWAY with the"
    echo "URL bar of your web browser. Login to your router and continue"
    echo "to the port forwarding section and port forward..."
    echo "$LANIP TCP/UDP 5889"
    echo
    echo "What is a full node? It is a Vertcoin server that contains the"
    echo "full blockchain and propagates transactions throughout the Vertcoin"
    echo "network via peers). Playing its part to keep the Vertcoin peer-to-peer"
    echo "network healthy and strong."
    echo
    echo "Useful commands to know:"
    echo "------------------------------------------------------------------------------"
    echo " htop                                 | task manager / resource monitor"
    echo " ifconfig                             | display network interface IP addresses"
    echo " vertcoin-cli getblockchaininfo       | display blockchain information"
    echo " vertcoin-cli getblockcount           | display current number of blocks"
    echo " vertcoin-cli getconnectioncount      | display number of connections"
    echo " vertcoin-cli getnettotals            | display total number of bytes sent/recv"
    echo " vertcoin-cli getnewaddress           | generate bech32 (segwit) address"
    echo " vertcoin-cli getnewaddress "\"""\"" legacy | generate legacy address"
    echo
    echo " # display latest vertcoin log information: " 
    echo " tail -f ~/.vertcoin/debug.log"
    echo
    if [[ $INSTALLP2POOL = "install_p2pool" ]]; then
        # if p2pool was installed display this information
        echo " # display latest p2pool log information: " 
        echo " tail -f ~/p2pool-vtc/data/vertcoin/log"
        echo
    else
        # else do nothing and proceed 
        :        
    fi
    echo "------------------------------------------------------------------------------"
}

# -------------BEGIN-MAIN-------------------


# clear the screen
clear
user_intro
clear
# check parameters
while test $# -gt 0
do
    key="$1"
    if [ "$key" = "secure" ]; 
    then
        secure; exit 1
    else
        redtext 'Unknown parameter'; exit 1
    fi
done
# call user_input function | take user input for rpcuser and rpcpass
clear
user_input
clear
compile_or_compiled
clear
prompt_p2pool
clear
# prompt user to load blockchain
load_blockchain
clear
init_script
# call update_rasp function | update the system
update_rasp
# call install_depends function | install the required dependencies to run this script
install_depends
# call secure function | modify iptables to limit connections for security purposes
secure
# configure USB flash drive ; call hd_config function, then call swap_config function
if [ "$DRIVE_CONF" = "true" ]; then
    hd_config
    swap_config
fi
# call userinput_vertcoin and build from source or grab release
userinput_vertcoin
# configure crontab for vertcoin
config_crontab
# call config_vertcoin | create ~/.vertcoin/vertcoin.conf to configure vertcoind
config_vertcoin
# call userinput_p2pool
userinput_p2pool
# execute on blockchain loading method
initiate_blockchain
# display post installation results
installation_report