AnglerBerry
===========

Raspberry Pi - 3G/LAN Captive Portal
- takes Internet from 3G/4G USB dongle (tested on Huawei E3131)
- gives wireless access over WiPi USB dongle
- can be used as a normal wifi router
   * Wifi access point with password
   * gives IP addresses (DHCP server)
   * forwards all traffic to internet
   * security measures (block certain ports)
- can be a captive portal: 
   * Wifi access point without Internet access
   * 1st time users are redirected to splash page
   * after accepting the conditions/giving a code, they get Internet access


Inspired by:
   * https://github.com/thgh/pilon
   * https://github.com/harryallerston/RPI-Wireless-Hotspot
