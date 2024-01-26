#!/bin/bash

##############################################
# Flash the action led to indicate the IP address
# of this server.
#
# Written by Paul Pearce - January 2024
#
##############################################
# Determine this server's IP address
#
INTERFACE=$(/usr/sbin/route -n | /usr/bin/grep UG | /usr/bin/sort -k 5 | /usr/bin/awk '{ print $8}' | /usr/bin/head -n 1)
MY_FULL_IP=$(/usr/sbin/ifconfig $INTERFACE | /usr/bin/grep 'inet ' | /usr/bin/awk '{ print $2}')

##################
# The led to flash
#
LED='/sys/class/leds/ACT'
##############################################

#################
function quit() {
#################
   local exitValue=${1:-1}

   if [ -z "$SIM" ]
   then
      /usr/bin/echo mmc0 >"${LED}/trigger"
   else
      /usr/bin/echo "# Handle quit with [$exitValue]"
   fi

   exit $exitValue
}

###################
function snooze() {
###################
   local s="$1"

   if [ -z "$SIM" ]
   then
      /usr/bin/sleep $s
   else
      /usr/bin/echo -e "# Sleep ${s}s"
   fi
}

######################
function flash-bit() {
######################
   local time_on=${1:-1}

   if [ -z "$SIM" ]
   then
      # Turn on LED
      /usr/bin/echo 1 >"${LED}/brightness"


      # delay
      snooze $time_on

      # Turn off LED
      /usr/bin/echo 0 >"${LED}/brightness"
   else
      /usr/bin/echo "flash ${time_on}s"
   fi
}

########################
function flash-digit() {
########################
   local digit=$1

   if [ ! -z "$SIM" ]
   then
      /usr/bin/echo "##############"
      /usr/bin/echo "# Digit $digit"
   fi

   if [ $digit -gt 0 ]
   then
      while [ $digit -gt 0 ]
      do
         flash-bit
         snooze 0.8
         ((digit--))
      done
   else
     flash-bit 0.1 
     snooze 0.8
   fi
   snooze 2
}

########################
function flash-octet() {
########################
   local octet=$1
   local index=0
   local l=${#octet} 
   local c=''

   if [ ! -z "$SIM" ]
   then
      /usr/bin/echo "##############"
      /usr/bin/echo "# Octet $octet"
   fi

   while [ $l -gt 0 ]
   do
      c=${octet:$index:1}
      flash-digit $c

      if [ $l -gt 1 ]
      then
         flashes 2
         snooze 2
      fi

      ((l--))
      ((index++))
   done
}

##################
function flashes() {
##################
   count=${1:-1}

   while [ $count -gt 0 ]
   do
     flash-bit 0.1
     snooze 0.1
     
     ((count--))
   done
}

#################
function help() {
#################
   /usr/bin/echo "# Blinking Raspberry Pi's Action LED with IP - press CTRL-C to quit"
   /usr/bin/echo "#"
   /usr/bin/echo "# Usage:" 
   /usr/bin/echo "#    $0           - This help display."
   /usr/bin/echo "#    $0 'THIS_IP' - Flash the IP address of this server."
   /usr/bin/echo "#    $0 {octets}  - Flash the specified octets (space separate)."
   /usr/bin/echo "#"
   /usr/bin/echo "# Notes:"
   /usr/bin/echo "#    9 quick led flashes           = start of IP rendering"
   /usr/bin/echo "#    4 quick led flashes           = between octets"
   /usr/bin/echo "#    2 quick led flashes           = between digits of octet"
   /usr/bin/echo "#    6 quick led flashes           = end   of IP rendering"
   /usr/bin/echo "#    Single quick led flash        = digit 0"
   /usr/bin/echo "#    Multiple 1 second led flashes = digit 1-9"
   /usr/bin/echo "#"
   /usr/bin/echo "# Set SIM env. variable to a non empty value to simulate led flashing."
   /usr/bin/echo "# If the 1st two octets of a 4 octet IP address are 192 168, they will be skipped."

   exit 0
}

####################################################################################
####################################################################################
# Handle any signals received
#
trap SIGINT SIGTERM SIGQUIT


##########################
# Examine the command line
#
if [ "$#" -lt 1 ]
then 
   help
else
   case "$1" in
      "THIS_IP") 
         IP="$(/usr/bin/echo $MY_FULL_IP | /usr/bin/tr '.' ' ')"
            ;;
      *) IP="$@"
            ;;
   esac
fi

if [ -z "$SIM" ]
then
   if ! [ $(id -u) = 0 ]; then
      /usr/bin/echo "Must be run as root."
      exit 1
   fi
else
   /usr/bin/echo "# IP [$@]"
fi

set -- $IP

if [ -z "$SIM" ]
then
   ##################################################
   # Use the last 2 octets if the 1st two are 192 168
   #
   if [ $# -eq 4 ]
   then
      if [ "$1" == "192" ]
      then
         if [ "$2" == "168" ]
         then
            shift ; shift
         fi
      fi
   fi
fi

if [ -z "$SIM" ]
then
   ####################
   # Initialise the led
   #
   /usr/bin/echo none >"${LED}/trigger"
fi

if [ ! -z "$SIM" ]
then
   /usr/bin/echo "##########"
   /usr/bin/echo "# Preamble"
fi

flashes 9
snooze 1

##############
# Flash the IP octets
#
while [ $# -gt 0 ]
do
   flash-octet ${1}

   if [ $# -gt 1 ]
   then
      flashes 4
      snooze 1
   fi

   shift
done

snooze 1

if [ ! -z "$SIM" ]
then
   /usr/bin/echo "##########"
   /usr/bin/echo "# Postable"
fi

flashes 6

quit 0
