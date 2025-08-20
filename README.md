# SuiteCRM_Script

![alt text](/logo_x2.png)

Installing SuiteCRM 8.8.1 Easily with a Script File

There isn't much user-friendly documentation available for easily installing this great CRM, so I created a tested SuiteCRM installation script that will allow you to install it on a Linux computer or a virtual Linux machine in under 10 minutes.

Steps to follow:

 1. This script was tested in a Ubuntu server 22.04
 2. Copy the .sh file into your machine.
 3. Change the permissions of the new .sh file using this command    `
	```
	sudo chmod +x "yourfilename".sh
	```

4. To run the new script use the following command
	```
	sudo ./"yourfilename".sh  
	```    
	> Follow the script and  take note of the requested database's username, password, and port number

  5. When the script finishes run the command
		```
		sudo mysql_secure_installation
		```

		
		- Just press enter (there is no root password)
		- Switch to unix_socket authentication [Y/n] Y 
		- Change the root password? [Y/n] Y   
			- Put your DB root password and take note of it!!! 
		- Remove anonymous users? [Y/n] Y 
		- Disallow root login remotely? [Y/n] Y 
		- Remove test database and access to it? [Y/n] Y
		- Reload privilege tables now? [Y/n] Y
    
  6. On the database configuration website these are the fields:
  
| Details | Value |
|--|--|
| SuiteCRM Database User | USER THAT YOU CHOOSE ON THE SCRIPT |
| SuiteCRM Database User Password| PASSWORD THAT YOU CHOOSE ON THE SCRIPT|
| Host Name | localhost |
| Database Name | CRM |
| Port | PORT THAT YOU ENTERED ON THE SCRIPT|

[This is the install video for easy life](https://youtu.be/eycqCChZ8nI).
