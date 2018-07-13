# SUSE’s openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC                                                                                    
# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary:  Based on consoltest_setup.pm (console test pre setup, stopping and disabling packagekit, install curl and tar to get logs and so on)
# modified for running the testcase TOOL_s390_vmcp on s390x.

use base "consoletest";
use testapi;
use utils;
use strict;

sub run {
    my $self = shift;

    # start of modification for s390 test TOOL_s390_vmcp
    script_run "mkdir TOOL_s390_vmcp";
    script_run "cd TOOL_s390_vmcp";
    assert_script_run "wget " . data_url('s390-tests/vmcp_main.sh');
    assert_script_run "wget " . data_url('s390-tests/common.sh');
    script_run "chmod +x ./*.sh";
    assert_script_run "./vmcp_main.sh > vmcp_main.log";
    upload_logs('vmcp_main.log');
    # end of modification for s390 test

    save_screenshot;
}

sub post_fail_hook {
    my $self = shift;

    $self->export_logs();
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
