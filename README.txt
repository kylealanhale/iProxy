Easy way to get an internet connection on your computer without jailbreaking. It's also easy to configure :
+ make a wifi on your computer
+ join the wifi from your iphone
+ open iProxy on your iphone
+ turn on the socks proxy
+ open iProxyMacSetup on your mac
+ click on "Start"


To use ssh on you computer, add this line in /etc/ssh_config
ProxyCommand /usr/bin/nc -X 5 -x iPhone.local:1080 %h %p

(replace iPhone.local by the name of iphone)



-----
With xcode 4, if you have a problem to run the application (unknown iProxyAppDelegate class), delete the application (in the simulator or the iphone), and choose iOS 4.2 (instead of 4.3) and run again.
