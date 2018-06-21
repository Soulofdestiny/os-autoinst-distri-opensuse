# SUSE’s openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: helper functions for s390 console tests

package s390base;
use base "consoletest";
use testapi;
use utils;
use strict;

sub copy_testsuite {
    my ($self, $tc) = @_;
    select_console 'root-console';


    # start of modification for s390 test TOOL_s390_vmcp
    my $script  = "$tc.sh";
    my $path    = data_url("s390x");
    my $script_path = "$path/$tc/$script";
    assert_script_run "mkdir -p ./tmp/ && cd ./tmp/";
    assert_script_run "wget -r -l1 -H -t1 -nd -N -np -A.sh -erobots=off $script_path";

    my $commonsh_path = "$path/lib/common.sh";
    assert_script_run "curl -f -v $commonsh_path > common.sh";
    assert_script_run "chmod +x ./*.sh";
    save_screenshot;
}

sub execute_script {
    my ($self, $script) = @_;
    assert_script_run "./$script | tee $script.log /dev/$serialdev";
    save_screenshot;
    upload_logs "$script.log";
}

sub cleanup_testsuite {
    return 1;
    # FIXME assert_script_run 'cd / && rm -rf ./tmp';
}


1;
# vim: set sw=4 et:
