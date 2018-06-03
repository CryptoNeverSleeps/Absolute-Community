![](https://www.absolutecoin.net/images/ABS-Logo-160x160.png)

# Absolute v12.2.2 Masternode Setup Guide [ Ubuntu 16.04 ]
```
THIS GUIDE WILL CREATE A NEW USER -
```
# MUST BE INSTALLED UNDER ROOT USER


Shell script to install a [Absolute Masternode](https://www.absolutecoin.net/) on a Linux server running Ubuntu 16.04. Use it on your own risk.
***

## Private Key

**This script can generate a private key for you, or you can generate your own private key on the Desktop software.**

Steps generate your own private key. 
1.  Download and install Absolute v12.2.2 for Windows -   
Download Link  - https://github.com/absolute-community/absolute/releases
2.  Open Absoulte Wallet
3.  Go to **Tools -> Click "Debug Console"** 
4.  Type the following command: **masternode genkey**  
5.  You now have your generated **Private Key**  (MasternodePrivKey)


## VPS installation
```
wget -q https://github.com/CryptoNeverSleeps/Absolute-Community/raw/master/abs_install.sh
bash abs_install.sh
```
Once the VPS installation is finished.

# Write Down or Copy Your User Password that was generated 

Check the block height

We want the blocks to match whats on the Absolute block explorer (https://explorer.absolutecoin.net/)

Once they match you can proceed with the rest of the guide.

Check the block height with the following command
```
watch absolute-cli getinfo
```

Once the block height matches the block explorer issue the following command.
```
CTRL and C  at the same time  (CTRL KEY and C KEY)
```
***

## Desktop wallet setup  

After the MN is up and running, you need to configure the desktop wallet accordingly. Here are the steps:  
1. Open the Absolute Desktop Wallet.  
2. Go to RECEIVE and create a New Address: **MN1**  
3. Send **1000** ABS to **MN1**. You need to send all 1000 coins in one single transaction.
4. Wait for 15 confirmations.  
5. Go to **Tools -> Click "Debug Console"** 
6. Type the following command: **masternode outputs**  
7. Go to  **Tools -> "Open Masternode Configuration File"**
8. Add the following entry:
```
Alias Address Privkey TxHash TxIndex
```
* Alias: **MN1**
* Address: **VPS_IP:PORT**
* Privkey: **Masternode Private Key**
* TxHash: **First value from Step 6**
* TxIndex:  **Second value from Step 6**
9. Save and close the file.
10. Go to **Masternode Tab**. If you tab is not shown, please enable it from: **Settings - Options - Wallet - Show Masternodes Tab**
11. Click **Update status** to see your node. If it is not shown, close the wallet and start it again. Make sure the wallet is un
12. Select your MN and click **Start Alias** to start it.
13. Alternatively, open **Debug Console** and type:
```
masternode start-alias MN1
``` 
14. Login to your VPS and check your masternode status by running the following command:.
```
absolute-cli masternode status
```
***

## Usage:
```
absolute-cli masternode status  
absolute-cli getinfo
```
Also, if you want to check/start/stop **Absolute**, run one of the following commands as **user**:

# To switch user -                  (absuser =   Your Username Created)
Type             
```
su absuser
```

```
systemctl status absuser.service            #To check if Absolute service is running  
systemctl start absuser.service             #To start Absolute service  
systemctl stop absuser.service              #To stop Absolute service  
systemctl is-enabled absuser.service        #To check if Absolute service is enabled on boot  
```  
***

## Donations

Any donation is highly appreciated

**ABS**:   ASxaBbTWqnqs7GYsFR5ZhSKVyQoVm9VqLd
**BTC**:   32PN27dDZhUYAmyJTWuzDvNscbVpkL9855  
**ETH**:   0x02680cdF57EEDC20C8A12036CA03e8D5F813b33b  
**LTC**:   MKYX9Pm58z6xSWT4Rc3CynjR58nj8hKo4F  
