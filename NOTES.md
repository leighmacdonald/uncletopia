# General Notes

These are just loose notes of things ive done to the system to enable the 
operation. It broadly describes how you can set up a system from scratch.

## Base System Setup

- adduser tf2server
- wget -O linuxgsm.sh https://linuxgsm.sh && chmod +x linuxgsm.sh && bash linuxgsm.sh tf2server 
- ./tf2server install    

2. Setup groups / users
    - `groupadd -g 2000 tf2`
    - `useradd -G tf2 -m -s /bin/zsh -u 2000 roto`
    - Add sudo permissions for the `tf2` group using `visudo`
        - `%tf2 ALL=(ALL) NOPASSWD:ALL`


3. SSH Setup
    - If needed, generate a key-pair
        - `ssh-keygen`
    - Add ssh keys for the users on each host @ `~/.ssh/authorized_keys` 
    - Disable root login in `/etc/ssh/sshd_config`
    - Restart ssh `systemctl restart ssh`

     
     
TODO

    rm /etc/apt/apt.conf.d/20auto-upgrades