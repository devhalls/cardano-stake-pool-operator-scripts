#!/bin/bash
# Usage: network.sh (
#   ngrok |
#   set_ip [ipAddress <STRING>] |
#   help [-h]
# )
#
# Info:
#
#   - ngrok) Install and setup an ngrok TCP service.
#   - set_ip) Set a fixed IP address for the devices default network interface.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/common.sh"

# Private functions

_network_die() {
    print 'ERROR' "$1" $red
    return 1
}

_network_fail() {
    _network_die "$1" || return 1
}

_require_warm_node() {
    if is_cold_device; then
        _network_fail 'This command can not be run on a cold device'
    fi
}

# Public functions

network_ngrok_install() {
    _require_warm_node || return 1
    local servicesDir="$(dirname "$0")/../services"

    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc |
        sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null &&
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" |
        sudo tee /etc/apt/sources.list.d/ngrok.list &&
        sudo apt install ngrok || _network_fail 'Could not install ngrok' || return 1

    cp -p $servicesDir/ngrok.service $servicesDir/$NGROK_SERVICE.temp
    sed -i $servicesDir/$NGROK_SERVICE.temp \
        -e "s|NODE_USER|$NODE_USER|g" \
        -e "s|NGROK_REGION|$NGROK_REGION|g" \
        -e "s|NGROK_ADDR|$NGROK_ADDR|g" \
        -e "s|NODE_PORT|$NODE_PORT|g"
    sudo cp -p $servicesDir/$NGROK_SERVICE.temp $SERVICE_PATH/$NGROK_SERVICE || _network_fail 'Could not install ngrok service' || return 1

    rm $servicesDir/$NGROK_SERVICE.temp
    ngrok config add-authtoken $NGROK_TOKEN || _network_fail 'Could not configure ngrok authtoken' || return 1
    sudo systemctl daemon-reload || _network_fail 'Could not reload systemd' || return 1
    sudo systemctl enable $NGROK_SERVICE || _network_fail 'Could not enable ngrok service' || return 1
    sudo systemctl start $NGROK_SERVICE || _network_fail 'Could not start ngrok service' || return 1
    print 'NETWORK' "Ngrok installed for edge $NGROK_EDGE" $green
    return 0
}

network_set_ip() {
    print 'NETWORK' 'Setting fixed IP address for your device'
    sudo $PACKAGER install net-tools -y || _network_fail 'Could not install net-tools' || return 1

    local ipAddress=${1:-$(hostname -I | awk '{print $1}')}
    local router=$(ip r | grep -m 1 default | awk '{print $3}')
    local interface=$(route | grep -m 1 '^default' | grep -o '[^ ]*$')

    update_or_append "/etc/dhcpcd.conf" "# Added by node scripts" "# Added by node scripts"
    update_or_append "/etc/dhcpcd.conf" "interface" "interface $interface"
    update_or_append "/etc/dhcpcd.conf" "static ip_address" "static ip_address=$ipAddress/24"
    update_or_append "/etc/dhcpcd.conf" "static routers" "static routers=$router"
    update_or_append "/etc/dhcpcd.conf" "static domain_name_servers" "static domain_name_servers=$router"
    sudo systemctl status systemd-networkd

    print 'NETWORK' "IP address set to $ipAddress. Restart your device for this change to take effect." $green
    return 0
}

case $1 in
    ngrok) network_ngrok_install ;;
    set_ip) network_set_ip "${@:2}" ;;
    help) help "${2:-"--help"}" ;;
    *) help "${1:-"--help"}" ;;
esac
exit $?
