#!/usr/bin/perl
###############

##
#         Name: Nop.pm
#       Author: spoonm
#      Version: $Revision$
#      License:
#
#      This file is part of the Metasploit Exploit Framework
#      and is subject to the same licenses and copyrights as
#      the rest of this package.
#
##

package Msf::Nop;
$VERSION = 2.0;
use strict;
use base 'Msf::Module';

sub new {
  my $class = shift;
  my $hash = @_ ? shift : { };
  my $self = $class->SUPER::new($hash);
  return($self);
}

sub Nops {
  return;
}

1;
