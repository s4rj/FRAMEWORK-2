#!/usr/bin/perl
###############

##
#         Name: SPARC.pm
#       Author: vlad902 <vlad902 [at] gmail.com>
#      Version: $Revision$
#      License:
#
#      This file is part of the Metasploit Exploit Framework
#      and is subject to the same licenses and copyrights as
#      the rest of this package.
#
##

package Pex::SPARC;
use strict;

# Register encodings (%g0 .. %i7)
# We could do %r00 .. %r31 too but who uses that?
my %registers =	(
			"g0",  0, "g1",  1, "g2",  2, "g3",  3,
			"g4",  4, "g5",  5, "g6",  6, "g7",  7,
			"o0",  8, "o1",  9, "o2", 10, "o3", 11,
			"o4", 12, "o5", 13, "o6", 14, "o7", 15,
			"l0", 16, "l1", 17, "l2", 18, "l3", 19,
			"l4", 20, "l5", 21, "l6", 22, "l7", 23,
			"i0", 24, "i1", 25, "i2", 26, "i3", 27,
			"i4", 28, "i5", 29, "i6", 30, "i7", 31
		);


sub sethi {
  my $constant = shift;
  my $dst = shift;

# [ 0 ] [ register ] [ 4 ] [ imm22 ]
# 31    29           24    21      0
  return pack("N", (($registers{$dst} << 25) | (4 << 22) | ($constant >> 10)));
}

sub ori {
  my $src = shift;
  my $constant = shift;
  my $dst = shift;

# [ 2 ] [ dst register ] [ 2 ] [ src register ] [ 1 ] [ simm13 ]
# 31    29               24    18               13    12       0
  return pack("N", ((2 << 30) | ($registers{$dst} << 25) | (2 << 19) | ($registers{$src} << 14) | (1 << 13) | ($constant & 0x1fff)));
}

sub set {
  my $constant = shift;
  my $dst = shift;

# Only use ori() with sethi() if the bottom 10 bits need to be set.
  if($constant & 0x3ff)
  {
    return sethi($constant, $dst) . ori($dst, $constant & 0x3ff, $dst);
  }
  else
  {
    return sethi($constant, $dst);
  }
}

1;