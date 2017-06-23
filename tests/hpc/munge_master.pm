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

sub exec_and_insert_password {
    my ($cmd) = @_;
    type_string $cmd;
    send_key "ret";
    assert_screen('password-prompt', 60);
    type_password;
    send_key "ret";
}

sub run() {
    my $host_ip = "10.0.2.10/15";
    my $slave_ip = "10.0.2.11";
    barrier_create("installation_finished", 2);   
    barrier_create("service_enabled", 2);   

    
    wait_still_screen 10;  

    select_console 'root-console';

    # Setup static NETWORK
    configure_default_gateway;
    configure_static_ip($host_ip);
    configure_static_dns(get_host_resolv_conf());

    # check if gateway is reachable
    assert_script_run "ping -c 1 10.0.2.2 || journalctl -b --no-pager >/dev/$serialdev";

    # set proper hostname
    assert_script_run('hostnamectl set-hostname munge-master');

    zypper_call('in munge libmunge2');

    barrier_wait('installation_finished'); 

    exec_and_insert_password("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root@$slave_ip:/etc/munge/munge.key");
    
    mutex_create('key_copied');
    
    assert_script_run('systemctl enable munge.service');
    assert_script_run('systemctl start munge.service');

    barrier_wait("service_enabled");

    assert_script_run('munge -n');
    assert_script_run('munge -n | unmunge');
    exec_and_insert_password("munge -n | ssh $slave_ip unmunge");
    assert_script_run('remunge');
}

1;

# vim: set sw=4 et:

