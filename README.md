<p align="center">
  <img src="https://i.imgur.com/PJxYRgW.png" width="200" height="200" />
</p>

<p align="center">
  <img src="https://github.com/vertiond/documents/blob/main/vertnode/vertnode.png" width="425" height="68" /> <img src="https://i.imgur.com/1RKi4wd.png" width="90">
</p>

## [Vertcoin.org](https://vertcoin.org/)

------------

# Vertnode 
## An automated solution for installing Vertcoin node(s) on Single Board Computers and `amd64` compatible hardware

**`NOTE:` The steps provided below produce a “headless” server... meaning we will not be using a GUI to configure Vertcoin or check to see how things are running. In fact, once the server is set up, you will only interact with it using command line calls over `SSH`. The idea is to have this full node be simple, low-power, with optimized memory usage and something that “just runs” in your basement, closet, etc.**

**vertnode allows you to sync from scratch or from your own blocks data.**

### Functioning Status
- [x] `Working` **Raspberry Pi 4** | Quad core Cortex-A72 1.5GHz | 2GB-8GB SDRAM | 
- [ ] `Working` **Intel NUC** | Dual-Core 2.16 GHz Intel Celeron | 8GB DDR3 RAM |
- [ ] `Working` **Rock64 Media Board** | Quad-Core ARM Cortex A53 64-Bit CPU | 4GB LPDDR3 RAM | 

### **`Optional P2Pool Installation Requires Minimum 4GB RAM`**
### **`USB flash drive required: 16GB >`**

### Supported
- [x] **Raspberry Pi 4 | [Raspberry Pi OS Lite](https://www.raspberrypi.org/software/operating-systems/)**
- [x] **Rock64 Media Board | [Debian Stretch Minimal](https://github.com/ayufan-rock64/linux-build/releases/download/0.6.15/stretch-minimal-rock64-0.6.15-175-arm64.img.xz)**
- [x] **Intel NUC | [Ubuntu Server 16.04](http://releases.ubuntu.com/16.04/ubuntu-16.04.4-server-amd64.iso)**

---------------
### 1.) Parts List
|                                                                                      Name                                                                                      |    Price    |                                         URL                                        |
|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|:-----------:|:----------------------------------------------------------------------------------:|
|                                                                                **Raspberry Pi**                                                                                |   -------   | NOTE: 2GB is minimum for Core; 4GB is minimum for Core+P2Pool; 8GB is recommended for all intensive purposes |              |
|                                                            CanaKit Raspberry Pi 4 Basic Kit (2GB, 4GB, 8GB RAM) 			                                                            | $55-$90 USD | https://www.amazon.com/CanaKit-Raspberry-Basic-Kit-8GB/dp/B07TYK4RL8               |
|                                                      **Required hardware**     | -------             |                                                                                    |
|                                               **MicroSD Memory Card** - Samsung 32GB 95MB/s (U1) MicroSD EVO Select Memory Card                                                |  $7.49 USD  | https://www.amazon.com/Samsung-MicroSD-Adapter-MB-ME32GA-AM/dp/B06XWN9Q99/         |
|                                                       **USB Flash Drive** - SanDisk 16GB Ultra Flair USB 3.0 Flash Drive                                                       |  $6.99 USD  | https://www.amazon.com/SanDisk-Ultra-Flair-Flash-Drive/dp/B015CH1GTO/            |
|                                             **MicroSD Card Reader** - Transcend USB 3.0 SDHC / SDXC / microSDHC / SDXC Card Reader                                             | $9.95 USD           | https://www.amazon.com/Transcend-microSDHC-Reader-TS-RDF5K-Black/dp/B009D79VH4/    |
|                                 **[Sufficient Power Supply](https://www.raspberrypi.org/documentation/hardware/raspberrypi/power/README.md)**                                  | ~ $10 USD           | -------    |
|                                                                        *OPTIONAL: Case with Cooling Fan                                                                        | ~ $10 USD          | -------   |

------------------------
---------------

### 2.) Install Raspberry Pi OS Lite

>[Raspberry Pi OS](https://www.raspberrypi.org/documentation/raspbian/) is a free operating system based on Debian, optimised for the Raspberry Pi hardware. Raspberry Pi OS comes with over 35,000 packages: precompiled software bundled in a nice format for easy installation on your Raspberry Pi.

Download [Raspberry Pi Imager](https://www.raspberrypi.org/%20downloads/)   
Insert your MircoSD card into a USB MicroSD card reader and open Raspberry Pi Imager

Select [Raspberry Pi OS Lite (32-bit)](https://www.raspberrypi.org/software/operating-systems/), your target MicroSD card and Write!

![Choose-OS](https://github.com/vertiond/documents/blob/main/vertnode/raspberry-pi-imager.png)  
![Select-other](https://github.com/vertiond/documents/blob/main/vertnode/raspberry-pi-select-other.png)  
![Select-lite](https://github.com/vertiond/documents/blob/main/vertnode/raspberry-pi-os-lite.png)

Once Raspberry Pi Imager is finished writing to the MicroSD card please access the 'boot' partition of the MicroSD card with Windows Explorer `Win+E`. Create a new empty text file named `ssh` like so...

![MicroSD card - ssh](https://i.imgur.com/m14rGdV.png)  
This enables `SSH` access on the Raspberry Pi's first boot sequence. Please safely remove the USB Card Reader / MicroSD card as to ensure the data is not corrupted.

### How to enable wireless connection on boot if hard wiring is not available

Create another new text file named `wpa_supplicant.conf` that will hold the network info...

Edit the file that you just created adjusting for the name of your country code, network name and network password.

```
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="NETWORK-NAME"
    psk="NETWORK-PASSWORD"
}
```
Please safely remove the USB Card Reader / MicroSD card as to ensure the data is not corrupted.

Insert the MicroSD card that was safely removed into the microSD slot the Raspberry Pi. Once the Pi has booted it will attempt to join the wireless network using the information provided in the `wpa_supplicant.conf` file.

------------
### 3.) Initial Setup of Raspberry Pi

Insert the MicroSD card that was safely removed into the slot located on the bottom of the Raspberry Pi. Connect an Ethernet cable to the Raspberry Pi that has internet access. When you are ready to power on the Pi, plug the power supply in and the Raspberry Pi will immediately begin to boot.

We will access our Raspberry Pi through an `SSH` session on our Windows PC. I like to use `Git Bash` which is included in the Windows [download](https://git-scm.com/downloads) of `Git`.

Open a web browser, navigate to your router page and identify the `IP` address of the freshly powered on Raspberry Pi. In my case the `IP` address is `192.168.1.2`, please make note of your Raspberry Pi's `IP` address as we will need to use it to login via `SSH`.

Open `Git Bash` and ...  
`ssh 192.168.1.2 -l pi`   
Default password: `raspberry`

Change `user` password   
`passwd`

Change `root` password  
`sudo passwd root`

Download and install latest system updates  
`sudo apt update ; sudo apt upgrade -y ; sudo apt install git -y`

Download and install useful software packages   
`sudo apt install fail2ban -y`

>[Fail2ban](https://www.digitalocean.com/community/tutorials/how-fail2ban-works-to-protect-services-on-a-linux-server) is a daemon that can be run on your server to dynamically block clients that fail to authenticate correctly with your services repeatedly. This can help mitigate the affect of brute force attacks and illegitimate users of your services like `SSH`.

Initiate `raspi-config` script  
`sudo raspi-config`

```
1.) [8] Update				# update raspi-config script first
2.) [5] Localization Options       	
	> [L2] Change Timezone		# set your timezone
3.) [6] Advanced Options		
	> [A1] Expand Filesystem	# expand filesystem 
```
Use Tab to select `<Finish>` and choose to reboot.

Wait a minute, then log back in via `SSH`  
`ssh 192.168.1.2 -l pi`

------------
### 4.) Automated installation
**Ensure that you have an external USB drive that is >16GB attached**
```
git clone https://github.com/vertiond/vertnode && cd vertnode
./install-vertnode.sh 
```
---------------
### Updating Vertcoin-Core to the latest version for those who have previously used this software
**`ssh` into the device and issue these commands, making sure to replace the links and folder names with the version of Vertcoin-Core you wish to update to**
```
vertcoin-cli stop
wget https://github.com/vertcoin-project/vertcoin-core/releases/download/0.18.0-rc1/vertcoind-v0.18.0-rc1-arm-linux-gnueabihf.zip
unzip vertcoind-v0.18.0-rc1-arm-linux-gnueabihf.zip
rm vertcoind-v0.18.0-rc1-arm-linux-gnueabihf.zip
sudo mv vertcoind vertcoin-tx vertcoin-cli vertcoin-wallet /usr/bin/
vertcoind -daemon
```
```
Useful commands to know:

htop                                 | task manager / resource monitor
ifconfig                             | display network interface IP addresses
vertcoin-cli getblockchaininfo       | display blockchain information
vertcoin-cli getblockcount           | display current number of blocks
vertcoin-cli getconnectioncount      | display number of connections
vertcoin-cli getnettotals            | display total number of bytes sent/recv
vertcoin-cli getnewaddress           | generate address
    
# display latest vertcoin log information: 
tail -f ~/.vertcoin/debug.log
```
----------------
### FAQ

#### Why a Vertcoin Full node?
Vertcoin is a digital currency supported by a peer-to-peer network. In order to run efficiently and effectively, it needs peers run by different people... and the more the better.

#### Why a Raspberry Pi?
Raspberry Pi is an inexpensive computing hardware platform that generates little heat, draws little power, and can run silently 24 hours a day without having to think about it.

#### What is a Full Node?

Vertcoin’s peer-to-peer network is composed of network "nodes," run mostly by volunteers. Those running vertcoin nodes have a direct and authoritative view of the vertcoin blockchain, with a local copy of all the transactions, independently validated by their own system and can initiate transactions directly on the vertcoin network.

By running a node, you don’t have to rely on any third party to validate a transaction. Moreover, **by running a vertcoin node you contribute to the vertcoin network by making it more robust**. A full-node client consumes substantial computer resources (e.g., more than `6 GB` of disk, `~2 GB` of `RAM` at most) but offers complete autonomy and independent transaction verification.

**Running a node, however, requires a permanently connected system with enough resources to process all vertcoin transactions.** Vertcoin nodes also transmit and receive vertcoin transactions and blocks, consuming internet bandwidth. If your internet connection is limited, has a low data cap, or is metered (charged by the gigabit), you should probably not run a vertcoin node on it, or run it in a way that limits its bandwidth usage.

Despite these resource requirements, hundreds of volunteers run vertcoin nodes. **Some are running on systems as simple as a [Raspberry Pi](https://www.canakit.com/raspberry-pi-4-4gb.html) (a $55 USD computer the size of a pack of cards)**. Many volunteers also run vertcoin nodes on rented servers, usually some variant of Linux. A Virtual Private Server (VPS) or Cloud Computing Server instance can be used to run a vertcoin node. Such servers can be rented for as low as $10 per month from a variety of providers.

#### Why run a headless node on a Single Board Computer?

1. You want to support vertcoin. Running a node makes the network more robust and able to serve more wallets, more users, and more transactions.
2. You are building or using applications such as mining that must validate transactions according to vertcoin’s consensus rules.
3. You are developing vertcoin software and need to rely on a vertcoin node for programmable (API) access to the network and blockchain.

**The idea is to have this full node be simple, low-power, with optimized memory usage and something that “just runs” in your basement, closet, etc.**

---------------
### [Manual Installation Walkthrough: Raspberry Pi 4](https://github.com/VertDocs/VertDocs/blob/master/docs/FullNodes/raspberry-pi.md)
### [Manual Installation Walkthrough: Intel NUC](https://github.com/vertcoin-project/VertDocs/blob/master/docs/FullNodes/intel-nuc.md)

---------------
### TO-DO Checklist
- [ ] adjust swap file size based on RAM
- [ ] expand support for x86_64 Debian / Ubuntu virtual machine, add option for USB flash drive
- [ ] add `md5` hash checksum to `vertcoind` and `p2pool` downloads
- [ ] add TOR network option

------------

<p align="center">
  <img src="https://i.imgur.com/TKEVSFv.png">
</p>

<p align="center">
  <img src="https://images-na.ssl-images-amazon.com/images/I/91AAiPdhwxL._SL1500_.jpg">
</p>

<p align="center">
  <img src="https://cdn.shopify.com/s/files/1/0569/7173/products/Rock64Wood_2_1024x1024.jpg?v=1510970757">
</p>

<p align="center">
  <img src="https://i.imgur.com/zgx4uiu.jpg">
</p>

<p align="center">
  <img src="https://images-na.ssl-images-amazon.com/images/I/61NNweC8vCL._SL1448_.jpg">
</p>

<p align="center">
  <img src="https://i.imgur.com/9T0gKr7.png">
</p>
