Tests for Elytron configuration module

Prerequisites:

These tests require libxml2 (for xmllint) and bats
 $ dnf install libxml2 bats

Running the tests:
 $ bats test/elytron.bats

You can get additional output by running:
 $ bats --tap test/elytron.bats

 (See the bats manpage for more information.)

