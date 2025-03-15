# linux_server
Guide to set up your own ssh linux server and to be able to access it from anywhere. Afterwards, how you can set up a script to run llm chats in the server.

## Router
1. Set fixed local IP for the device from the router (DHCP)
2. Use port forwarding (NAT Forwarding or Virtual Servers) from your router to redirect port 22 to the fixed local IP in port 22.


## ssh-config server
1. Install openssh-server

## ssh-config client
1. Install openssh
3. Set up your ssh with the router IP and the port
4. Set up the keys
5. If you are using custom cli prompts, make sure to write any non-ascii character with %{%GCHARACTER%} to avoid prompt corruption.

## Decryption on log-in
If your home drive is encrypted until password log-in and you want to automatically unencrypt on pubkey login... bad news. You can only automate the password prompt and unencryption.

1. A
2. 