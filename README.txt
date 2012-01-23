***** I won't update this project anymore. I don't have enough time, and tethering is free now in my country *****

Easy way to get an internet connection on your computer without jailbreaking. It's also easy to configure :
+ make a wifi on your computer
+ join the wifi from your iphone
+ open iProxy on your iphone
+ turn on the socks proxy
+ open iProxyMacSetup on your mac
+ click on "Start"

If you need ssh, open the preferences from iProxyMacSetup and check the ssh checkbox.

-----
To use iProxy with the proxy, iProxyMacSetup adds the following line into your ~/.ssh/config:
ProxyCommand /usr/bin/nc -X 5 -x <iphone ip/name>:1080 %h %p
(if you have any problems with ssh, please verify this or remove this line)

-----
to checkout the srelay submodule (but this should be done by the iProxy target, so no need to do it yourself) :
git submodule update --init
cd Libraries/srelay
git branch --track iproxy origin/iproxy
git checkout iproxy
