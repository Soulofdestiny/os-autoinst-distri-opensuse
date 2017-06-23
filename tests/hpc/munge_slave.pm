# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation of munge package from HPC module and sanity check
# of this package
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, soulofdestiny <mgriessmeier@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use mm_network;
use mmapi;

sub run() { 
    my $host_ip = "10.0.2.11/15";
    wait_still_screen 10;  
    select_console 'root-console';
    
    # Setup static NETWORK
    configure_default_gateway;
    configure_static_ip($host_ip);
    configure_static_dns(get_host_resolv_conf());
    
    # check if gateway is reachable
    assert_script_run "ping -c 1 10.0.2.2 || journalctl -b --no-pager >/dev/$serialdev";
    
    
    # stop firewall, so key can be copied
    assert_script_run "rcSuSEfirewall2 stop";

    
    # set proper hostname
    assert_script_run('hostnamectl set-hostname munge-slave');

    zypper_call('in munge libmunge2');

    barrier_wait('installation_finished'); 
    mutex_lock('key_copied');

    assert_script_run('systemctl enable munge.service');
    assert_script_run('systemctl start munge.service');
    
    barrier_wait("service_enabled");


    wait_for_children;
}

1;

# vim: set sw=4 et:

