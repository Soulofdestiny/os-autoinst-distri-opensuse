# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ghostscript testscripts 
# Maintainer: Stefan Fent <sf@suse.de>


use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';
    my $repo = "http://download.suse.de/ibs/home:/jsmeix/SUSE_Factory_Head/home:jsmeix.repo";
    zypper_call("ar -f $repo");
    zypper_call('--gpg-auto-import-keys ref');
    zypper_call('in ghostscript-testscripts');
    assert_script_run('/usr/share/ghostscript-testscripts/gsbigtest.sh', 3600);
    wait_serial ('foobar', 3600);
}

1;

