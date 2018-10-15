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
# modified for running the testcase TOOL_s390_qethqoat on s390x.

use base "consoletest";
use testapi;
use utils;
use strict;

sub run {
    my $self = shift;
    # let's see how it looks at the beginning
    save_screenshot;

    # Special keys like Ctrl-Alt-Fx does not work on Hyper-V atm. Alt-Fx however do.
    my $tty1_key = 'ctrl-alt-f1';
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        $tty1_key = 'alt-f1';
    }

    if (!check_var('ARCH', 's390x')) {
        # verify there is a text console on tty1
        for (1 .. 6) {
            send_key $tty1_key;
            if (check_screen("tty1-selected", 5)) {
                last;
            }
        }
        if (!check_screen "tty1-selected", 5) {    #workaround for bsc#977007
            record_soft_failure "unable to switch to the text mode";
            send_key 'ctrl-alt-backspace';         #kill X and log in again
            send_key 'ctrl-alt-backspace';
            assert_screen 'displaymanager', 200;    #copy from installation/first_boot.pm
            mouse_hide();
            if (get_var('DM_NEEDS_USERNAME')) {
                type_string $username;
            }
            if (match_has_tag("sddm")) {
                # make sure choose plasma5 session
                assert_and_click "sddm-sessions-list";
                assert_and_click "sddm-sessions-plasma5";
                assert_and_click "sddm-password-input";
            }
            else {
                wait_screen_change { send_key 'ret' };
            }
            type_string "$password";
            send_key "ret";
            send_key_until_needlematch "tty1-selected", $tty1_key, 6, 5;
        }
    }

    # init
    check_console_font;
    type_string "chown $username /dev/$serialdev\n";
    script_run 'echo "set -o pipefail" >> /etc/bash.bashrc.local';
    script_run '. /etc/bash.bashrc.local';
    # Export the existing status of running tasks and system load for future reference (fail would export it again)
    script_run "ps axf > /tmp/psaxf.log";
    script_run "cat /proc/loadavg > /tmp/loadavg_consoletest_setup.txt";

    # Just after the setup: let's see the network configuration
    save_screenshot;

    $self->clear_and_verify_console;


# start of modification for s390 test TOOL_s390_qethqoat    
    my $TC_PATH = get_var('TC_PATH') . "/TOOL_s390_qethqoat/";
    assert_script_run "wget -r -np -R 'index.html*'  $TC_PATH";
    script_run "cd $TC_PATH";
    my $COMMONSH_PATH = get_var('TC_PATH') . "/lib/common.sh";
    assert_script_run "wget $COMMONSH_PATH";

    script_run "chmod +x ./*.sh";
    assert_script_run "./10S_cleanup_qethqoat.sh";
    assert_script_run "./20S_prepare_qethqoat.sh";
    assert_script_run "./30S_test_qethqoat.sh";
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
