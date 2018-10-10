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
    select_console 'root-console';
    # start of modification for s390 test TOOL_s390_vmcp
    my $testset = get_var('IBM_TESTSET'); # e.g. "KERNEL or TOOL or MEMORY"
    my $tc = get_var('IBM_TESTS');
    my $path    = data_url("s390x");
    my $tc_tar_file = "${testset}_${tc}.tgz";
    my $tar_path = "${path}/${testset}_s390_${tc}/${tc_tar_file} ";
    my $sh_dir = "/root/tmp";
    my $lib_dir = "$sh_dir/lib";
    assert_script_run "mkdir -p $sh_dir";
    assert_script_run "wget -P $sh_dir -r -l1 -H -t1 -nd -N -np -R'index.html*' -erobots=off $tar_path";
    assert_script_run "tar xfv $sh_dir/$tc_tar_file -C $sh_dir";
    assert_script_run "chmod +x $sh_dir/*.sh";
    
    my $common_tar_file = "common.tgz";
    my $common_tar_path = "${path}/lib/$common_tar_file";
    assert_script_run "mkdir -p $lib_dir";
    assert_script_run "wget -P $lib_dir -r -l1 -H -t1 -nd -N -np -R'index.html*' -erobots=off $common_tar_path";
    assert_script_run "tar xfv $lib_dir/$common_tar_file -C $lib_dir";
    assert_script_run "chmod +x $lib_dir/*.sh";

    my $log_dir = "/root/tmp/logs";
    assert_script_run "mkdir -p $log_dir";
    save_screenshot;
}

sub handle_tarball {
    my ($path, $tarball) = @_;
    
    assert_script_run "wget -r -l1 -H -t1 -nd -N -np -R'index.html*' -erobots=off $path/$tarball";
    assert_script_run "tar xfv $tarball";



}

sub execute_script {
    my ($self, $script, $scriptargs, $timeout) = @_;
    # TODO logging, double code 
    my $sh_dir = "/root/tmp";
    my $log_dir = "/root/tmp/logs";
    # assert_script_run ("cd $sh_dir && ./$script $scriptargs", timeout => $timeout);
    assert_script_run ("cd $sh_dir && ./$script $scriptargs |& tee $log_dir/$script.log", timeout => $timeout);
    save_screenshot;
}

sub cleanup_testsuite {
    my ($self,$script) = @_;
    # TODO double code
    my $sh_dir = "/root/tmp";
    my $log_dir = "/root/tmp/logs";
    my $log_tar = "${log_dir}/${script}_logs.tar";
    assert_script_run "tar cfv $log_tar $log_dir/*.log";
    upload_logs "$log_tar";
    assert_script_run "rm -rf $sh_dir";
}


1;
# vim: set sw=4 et:
