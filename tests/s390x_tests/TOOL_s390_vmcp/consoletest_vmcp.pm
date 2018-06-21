# SUSE’s openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary:  Based on consoletest_setup.pm (console test pre setup, stopping and disabling packagekit, install curl and tar to get logs and so on)
# modified for running the testcase TOOL_s390_vmcp on s390x.

use base "consoletest";
use testapi;
use utils;
use strict;

sub run {
    my $self = shift;
    select_console 'root-console';

    # start of modification for s390 test TOOL_s390_vmcp
    my $script = "vmcp_main";
    my $TC_PATH = data_url("s390x");
    assert_script_run "curl -f -v $TC_PATH/$script.sh > $script.sh";


    my $COMMONSH_PATH = "$TC_PATH/lib/common.sh";
    assert_script_run "curl -f -v $COMMONSH_PATH > common.sh";
    assert_script_run "chmod +x ./*.sh";
    assert_script_run "./$script | tee $script.log /dev/$serialdev | grep 'Failed tests.*0'";
    upload_logs "$script.log";

    # end of modification for s390 test

    save_screenshot;
}

sub post_fail_hook {
    my $self = shift;

    $self->export_logs();
}

sub test_flags {
    return {milestone => 1};
}

1;
# vim: set sw=4 et:
