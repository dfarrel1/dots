#!/bin/bash
echo "log /var/log/openvpn.log" >> ~/Downloads/client.ovpn \
&& echo "management 127.0.0.1 6001" >> ~/Downloads/client.ovp \
&& cp ~/Downloads/client.ovpn /usr/local/etc/openvpn/client.ovpn