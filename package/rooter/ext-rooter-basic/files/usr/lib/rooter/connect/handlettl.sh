#!/bin/sh 

log() {
	modlog "TTL Settings $CURRMODEM" "$@"
}

delTTL() {
	FLG="0"
	exst=$(cat /etc/ttl.user | grep "#startTTL$CURRMODEM")
	if [ ! -z "$exst" ]; then
		cp /etc/ttl.user /etc/ttl.user.bk
		sed -i -e "s|iptables -t mangle -I POSTROUTING -o |iptables -t mangle -D POSTROUTING -o |g" /etc/ttl.user.bk
		sed -i -e "s|iptables -t mangle -I PREROUTING -i |iptables -t mangle -D PREROUTING -i |g" /etc/ttl.user.bk
		sed -i -e "s|ip6tables -t mangle -I POSTROUTING -o |ip6tables -t mangle -D POSTROUTING -o |g" /etc/ttl.user.bk
		sed -i -e "s|ip6tables -t mangle -I PREROUTING -i |ip6tables -t mangle -D PREROUTING -i $|g" /etc/ttl.user.bk
		rm -f /tmp/ttl.user
		run=0
		while IFS= read -r line; do
			if [ $run = "0" ]; then
				sttl=$line
				stx=$(echo "$sttl" | grep "#startTTL$CURRMODEM")
				if [ ! -z $stx ]; then
					run=1
				fi
			else
				sttl=$line
				stx=$(echo "$sttl" | grep "#endTTL$CURRMODEM")
				if [ ! -z $stx ]; then
					chmod 777 /tmp/ttl.user
					/tmp/ttl.user
					break
				fi
				echo "$sttl" >> /tmp/ttl.user
			fi
		done < /etc/ttl.user.bk
		cp /etc/ttl.user /etc/ttl.user.bk
		
		sed /"#startTTL$CURRMODEM"/,/"#endTTL$CURRMODEM"/d /etc/ttl.user.bk > /etc/ttl.user
		FLG="1"
	fi
}

CURRMODEM=$1
TTL="$2"
TTLOPTION="$3"

if [ $CURRMODEM = "0" ]; then
	IFACE="wan"
else
	IFACE=$(uci -q get modem.modem$CURRMODEM.interface)
fi

if [ "$TTL" = "0" ]; then
	ENB=$(uci -q get ttl.ttl.enabled)
	if [ $ENB = "1" ]; then
		TTL=$(uci -q get ttl.ttl.value)
		if [ -z "$TTL" ]; then
			TTL=65
		fi
	else
		delTTL
		log "Deleting TTL on interface $IFACE"
		exit 0
	fi
fi

if [ "$TTL" = "1" ]; then
	delTTL
	log "Deleting TTL on interface $IFACE"
	exit 0
fi

delTTL
VALUE="$TTL"
echo "#startTTL$CURRMODEM" >> /etc/ttl.user
log "Setting TTL $VALUE on interface $IFACE"
if [ "$TTL" = "TTL-INC 1" ]; then
	TTL="0"
fi

if [ $VALUE = "0" ]; then
	if [ "$TTLOPTION" = "0" ]; then
		echo "iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-inc 1" >> /etc/ttl.user
		log "iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-inc 1"
		echo "iptables -t mangle -I PREROUTING -i $IFACE -j TTL --ttl-inc 1" >> /etc/ttl.user
		log "iptables -t mangle -I PREROUTING -i $IFACE -j TTL --ttl-inc 1"
		iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-inc 1
		iptables -t mangle -I PREROUTING -i $IFACE -j TTL --ttl-inc 1
		if [ -e /usr/sbin/ip6tables ]; then
			echo "ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-inc 1" >> /etc/ttl.user
			log "ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-inc 1"
			echo "ip6tables -t mangle -I PREROUTING -i $IFACE -j HL --hl-inc 1" >> /etc/ttl.user
			log "ip6tables -t mangle -I PREROUTING -i $IFACE -j HL --hl-inc 1"
			ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-inc 1
			ip6tables -t mangle -I PREROUTING -i $IFACE -j HL --hl-inc 1
		fi
	else
		if [ "$TTLOPTION" = "1" ]; then
			echo "iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-inc 1" >> /etc/ttl.user
			log "iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-inc 1"
			iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-inc 1
			if [ -e /usr/sbin/ip6tables ]; then
				echo "ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-inc 1" >> /etc/ttl.user
				log "ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-inc 1"
				ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-inc 1
			fi
		else
			echo "iptables -t mangle -I POSTROUTING -o $IFACE ! -p icmp -j TTL --ttl-inc 1" >> /etc/ttl.user
			log "iptables -t mangle -I POSTROUTING -o $IFACE ! -p icmp -j TTL --ttl-inc 1"
			iptables -t mangle -I POSTROUTING -o $IFACE ! -p icmp -j TTL --ttl-inc 1
			if [ -e /usr/sbin/ip6tables ]; then
				echo "ip6tables -t mangle -I POSTROUTING -o $IFACE ! -p icmp -j HL --hl-inc 1" >> /etc/ttl.user
				log "ip6tables -t mangle -I POSTROUTING -o $IFACE ! -p icmp -j HL --hl-inc 1"
				ip6tables -t mangle -I POSTROUTING -o $IFACE ! -p icmp -j HL --hl-inc 1
			fi
		fi
	fi
else
	if [ "$TTLOPTION" = "0" ]; then
		echo "iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-set $VALUE" >> /etc/ttl.user
		log "iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-set $VALUE"
		echo "iptables -t mangle -I PREROUTING -i $IFACE -j TTL --ttl-set $VALUE" >> /etc/ttl.user
		log "iptables -t mangle -I PREROUTING -i $IFACE -j TTL --ttl-set $VALUE"
		iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-set $VALUE
		iptables -t mangle -I PREROUTING -i $IFACE -j TTL --ttl-set $VALUE
		if [ -e /usr/sbin/ip6tables ]; then
			echo "ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-set $VALUE" >> /etc/ttl.user
			log "ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-set $VALUE"
			echo "ip6tables -t mangle -I PREROUTING -i $IFACE -j HL --hl-set $VALUE" >> /etc/ttl.user
			log "ip6tables -t mangle -I PREROUTING -i $IFACE -j HL --hl-set $VALUE"
			ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-set $VALUE
			ip6tables -t mangle -I PREROUTING -i $IFACE -j HL --hl-set $VALUE
		fi
	else
		if [ "$TTLOPTION" = "1" ]; then
			echo "iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-set $VALUE" >> /etc/ttl.user
			log "iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-set $VALUE"
			iptables -t mangle -I POSTROUTING -o $IFACE -j TTL --ttl-set $VALUE
			if [ -e /usr/sbin/ip6tables ]; then
				echo "ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-set $VALUE" >> /etc/ttl.user
				log "ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-set $VALUE"
				ip6tables -t mangle -I POSTROUTING -o $IFACE -j HL --hl-set $VALUE
			fi
		else
			echo "iptables -t mangle -I POSTROUTING -o $IFACE ! -p icmp -j TTL --ttl-set $VALUE" >> /etc/ttl.user
			log "iptables -t mangle -I POSTROUTING -o $IFACE ! -p icmp -j TTL --ttl-set $VALUE"
			iptables -t mangle -I POSTROUTING -o $IFACE ! -p icmp -j TTL --ttl-set $VALUE
			if [ -e /usr/sbin/ip6tables ]; then
				echo "ip6tables -t mangle -I POSTROUTING -o $IFACE ! -p icmp -j HL --hl-set $VALUE" >> /etc/ttl.user
				log "ip6tables -t mangle -I POSTROUTING -o $IFACE ! -p icmp -j HL --hl-set $VALUE"
				ip6tables -t mangle -I POSTROUTING -o $IFACE ! -p icmp -j HL --hl-set $VALUE
			fi
		fi
	fi
fi
echo "#endTTL$CURRMODEM" >> /etc/ttl.user




