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
# modified for running the testcase TOOL_s390_fcp on s390x.


use base "s390base";
use testapi;
use utils;
use strict;

sub run {
    my $self = shift;
    my $LUN = get_var('PARM_LUN');
    my $WWPN = get_var('PARM_WWPN');
    my $ADAPTER = get_var('PARM_ADAPTER');
    $self->copy_testsuite('TOOL_s390_fcp');
    $self->execute_script('fcp_test_rc.sh',"$ADAPTER $WWPN $LUN",'1000');
    $self->cleanup_testsuite('TOOL_s390_fcp');
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
