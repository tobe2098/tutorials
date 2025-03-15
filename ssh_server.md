# linux_server
Guide to set up your own ssh linux server and to be able to access it from anywhere. Afterwards, how you can set up a script to run llm chats in the server.

## Router
1. Set fixed local IP for the device from the router (DHCP)
2. Use port forwarding (NAT Forwarding or Virtual Servers) from your router to redirect port 22 to the fixed local IP in port 22.


## ssh-config server
1. Install openssh-server
2. Activate the ssh daemon

```
sudo systemctl start sshd
sudo systemctl enable sshd
```

3. Set-up `sshd_config`, i.e.,
```
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile %h/.ssh/authorized_keys /var/ssh/%u/authorized_keys
ChallengeResponseAuthentication no
```
4. Restart the daemon
```
sudo systemctl restart sshd
```
## ssh-config client
- Install openssh
- Set up your ssh with the router IP and the port
- Create the keys and put the public key in `authorized_keys`
```
ssh-keygen -t ed25519 -C "your_email@example.com"
```
- Setup your `~/.ssh/config` with your server-side user. 
- If you are using custom cli prompts, make sure to write any non-ascii character with %{%GCHARACTER%} to avoid prompt corruption.
- Now ssh into the server:
```
ssh hostname
```

## Decryption on log-in
If your home drive is encrypted until password log-in and you want to automatically unencrypt on pubkey login... bad news. You can only automate the password prompt and unencryption.

1. A
2. 