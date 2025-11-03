#!/bin/sh

#Ensure onewifi is up and running
while [ ! -e /tmp/wifi_initialized ] && [ ! -e /tmp/wifi_dml_complete ] ; 
do   
   sleep 1; 
done

#work-around for initial start of agent
if [ ! -e /nvram/initial_restart_ctrl ]; then
sleep 8
systemctl stop em_ctrl
sleep 1 
systemctl start em_ctrl 
touch /nvram/initial_restart_ctrl
sleep 5
fi
