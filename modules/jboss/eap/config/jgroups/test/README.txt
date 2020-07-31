Tests for JGroups configuration module

Prerequisites:

These tests require libxml2 (for xmllint) and bats
 $ dnf install libxml2 bats

Running the tests:
 $ bats test/jgroups.bats

You can get additional output by running:
 $ bats --tap test/jgroups.bats

 (See the bats man page for more information.)

