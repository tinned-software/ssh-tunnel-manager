# SSH-Tunnel-Manager

The SSH-Tunnel-Manager is a bash shell script created to manage ssh tunnels.

This SSH-Tunnel-Manager script aims to setup one or more configured ssh connection with port forwarding. The list of functionality includes the following:

*     Multiple tunnels can be configured
*     Flexible configuration to forward mulitiple ports ber connection
*     Reconnect to the SSH server if connection lost
*     Log containing reconnect attempts
*     Maaging configured tunnels (start/stop/restart)


## Download & Installation

[Download Download SSH-Tunnel-Manager from Github](https://github.com/tinned-software/ssh-tunnel-manager)

To install the the script download it from Github and upload it to your server. Copy the example config file "**ssh-tunnel-manager.conf.example**" to "**ssh-tunnel-manager.conf**" and change its configuration values. The configuration file contains a description for its configuration items. To see the available commandline options execute "ssh-tunnel-manager.ssh -h".

## Description

Connecting to a service on a server that does not expose the service port or connection between servers not exposing there ports publicly is only possible via some kind of VPN or port forwarding. SSH port forwarding provides a simple port forwarding to the service you need to access.

With the SSH-Tunnel-Manager multiple SSH connections to different servers with different portforwardings can be configured. These tunnels can be comfortable managed. The script provides a start command to start the tunnels as well as a stop command to stop the running tunnels. The integrated logic will as well automatically restart the ssh tunnel if the connection to the ssh server should be lost.

The SSH-Tunnel-Manager script will establishing a ssh connection for every configured tunnel. Entering the password on every connect can be annoying. I suggest a [SSH passwordless login with SSH key](http://blog.tinned-software.net/ssh-passwordless-login-with-ssh-key/) setup. This allows the script to run without user interaction.
