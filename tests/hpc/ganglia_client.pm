# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ganglia Test - server
# Maintainer: soulofdestiny <mgriessmeier@suse.com>
# Tags: https://fate.suse.com/323979 

use base "hpcbase";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;

sub run {
    my $self = shift;

    # set proper hostname
    assert_script_run('hostnamectl set-hostname ganglia-client');

    # Prepare Client by installing "ganglia-gmond"
    zypper_call 'in ganglia-gmond';

    # Start gmond on Client
    systemctl "start gmond";

    # wait for server 
    barrier_wait('GANGLIA_INSTALLED');
    
    # Check if gmond has connected to gmetad
    # TODO some grep for both nodes
    # assert_script_run "gstat -a" or better script-output, for now only script_run
    script_run 'gstat -a';

    # Check if an arbitrary value could be sent via gmetric command
    # TODO assert_script_run 'gmetric -n \"TestMetric\" -v \"foobar\" -t string';
    # TODO assert_script_run 'nc ganglia-server 8649';
    script_run 'gmetric -n \"TestMetric\" -v \"foobar\" -t string';
    script_run 'nc ganglia-server 8649';

    
    barrier_wait('GANGLIA_SERVER_DONE');

    # 
    # # install munge, wait for master and munge key
    # zypper_call('in munge');
    # barrier_wait('MUNGE_INSTALLATION_FINISHED');
    # mutex_lock('MUNGE_KEY_COPIED');

    # # start and enable munge
    # $self->enable_and_start('munge');
    # barrier_wait("MUNGE_SERVICE_ENABLED");

    # # wait for master to finish
    # mutex_lock('MUNGE_DONE');
}

1;

# vim: set sw=4 et:

