#!/usr/bin/perl
###############

##
#         Name: UI.pm
#       Author: spoonm <ninjatools [at] hush.com>
#      Version: $Revision$
#  Description: Instantiable class allowing user interfaces access to the msf
#               framework (access to base, etc). Contains methods used by a ui.
#      License:
#
#      This file is part of the Metasploit Exploit Framework
#      and is subject to the same licenses and copyrights as
#      the rest of this package.
#
##

package Msf::UI;
use strict;
use base 'Msf::Base';
use Msf::Config;
use Pex::Encoder;
use Pex::Text;

sub new {
  my $class = shift;
  my $self = $class->SUPER::new({
    'BaseDir'  => shift,
    'ConfigFile' => @_ ? shift : 'config',
  });
  $self->_Initalize;
  return($self);
}

sub _BaseDir {
  my $self = shift;
  $self->{'BaseDir'} = shift if(@_);
  return($self->{'BaseDir'});
}
sub _ConfigFile {
  my $self = shift;
  $self->{'ConfigFile'} = shift if(@_);
  return($self->{'ConfigFile'});
}

sub _Initalize {
  my $self = shift;
  Msf::Config->PopulateConfig($self->ConfigFile);
}

sub ConfigFile {
  my $self = shift;
  return($self->_DotMsfDir ."/". $self->_ConfigFile);
}

sub _DotMsfDir {
  my $self = shift;
  my $dir = ($ENV{'HOME'}) ? $ENV{'HOME'} : $self->ScriptBase;
  return($dir . '/.msf');
}

sub LoadExploits {
  my $self = shift;
  my $dir = @_ ? shift : [
    $self->_BaseDir . '/exploits',
    $self->_DotMsfDir . '/exploits',
  ];
  return($self->LoadModules($dir, 'Msf::Exploit::'));
}
sub LoadEncoders {
  my $self = shift;
  my $dir = @_ ? shift : [
    $self->_BaseDir . '/encoders',
    $self->_DotMsfDir . '/encoders',
  ];
  return($self->LoadModules($dir, 'Msf::Encoder::'));
}
sub LoadNops {
  my $self = shift;
  my $dir = @_ ? shift : [
    $self->_BaseDir . '/nops',
    $self->_DotMsfDir . '/nops',
  ];
  return($self->LoadModules($dir, 'Msf::Nop::'));
}
sub LoadPayloads {
  my $self = shift;
  my $dir = @_ ? shift : [
    $self->_BaseDir . '/payloads',
    $self->_DotMsfDir . '/payloads',
  ];
  return($self->LoadModules($dir, 'Msf::Payload::'));
}

sub LoadModules {
  my $self = shift;
  my $dir = shift;
  my $prefix = shift;
  my $modules = { };

  my @dirs;

  if(ref($dir) eq 'ARRAY') {
    @dirs = @{$dir};
  }
  else {
    @dirs = ($dir);
  }

  foreach my $dir (@dirs) {

    next if(!-d $dir);
    next if(!opendir(DIR, $dir));

    while (defined(my $entry = readdir(DIR))) {
      my $path = "$dir/$entry";
      next if(!-f $path);
      next if(!-r $path);
      next if($entry !~ /.pm$/);

      $entry =~ s/\.pm$//g;
      $entry = $prefix . $entry;

      # remove the module from global namespace
      delete($::{$entry."::"});

      # load the module via do since we dont import
      $self->PrintDebugLine(3, "Doing $path");
      do $path;

      if($@) {
        $self->PrintLine("[*] Error loading $path: $@");
        delete($::{$entry."::"});
        next;
      }

      my $module = $entry->new();

      if(!$module->Loadable || $module->PrintError) {
        $self->PrintDebugLine(1, "[*] Loadable failed for $entry");
        delete($::{$entry."::"});
        next;
      }

      $modules->{$entry} = $module;
    }
    closedir(DIR);
  }

  return($modules);
}

sub MatchPayloads {
  my $self = shift;
  my $exploit = shift;
  my $payloads = shift;

  my $match = { };

CHECK:
  foreach my $payloadName (keys(%$payloads)) {
    my $payload = $payloads->{$payloadName};

    # If a exploit's arch or os is empty, it means they support allows
    # Same with a payload

    # Match the OS arrays of both the exploits and payloads
    # If an exploit has say 2 os's (linux and bsd maybe)
    # we will match all payloads that are linux or bsd
    if(@{$exploit->OS} && @{$payload->OS}) {
      my $valid = 0;
      foreach my $os (@{$payload->OS}) {
        $valid = 1 if(scalar(grep { $_ eq $os } @{$exploit->OS}));
      }
      if(!$valid) {
        # OS is not in payload
        $self->PrintDebugLine(3, $payload->SelfEndName . " failed, didn't match OS");
        next CHECK;
      }
    }
    
    # Match the Arch arrays of both the exploits and payloads
    if(@{$exploit->Arch} && @{$payload->Arch}) {
      my $valid = 0;
      foreach my $arch (@{$payload->Arch}) {
        $valid = 1 if(scalar(grep { $_ eq $arch } @{$exploit->Arch}));
      }
      if(!$valid) {
        # Arch is not in payload
        $self->PrintDebugLine(3, $payload->SelfEndName . " failed, didn't match Arch");
        next CHECK;
      }
    }

    # If the exploit has any keys set, we need to make sure that the
    # matched payload also has the same keys. This allows us to create
    # specific payloads for weird exploit scenarios (for instance, where
    # the process doesn't have a valid heap (hdm)
#    foreach my $key (@{$exploit->Keys}) {
#      if(!scalar(grep { $_ eq $key } @{$payload->Keys})) {
#        $self->PrintDebugLine(3, $payload->SelfEndName . " failed, keys do not match");
#        next CHECK;
#      }
#    }
#
#    # If the exploit has not Keys but the payload does, ignore it.
#    if (! scalar(@{$exploit->Keys}) && scalar(@{$payload->Keys}))
#    {
#        next CHECK;
#    }

    # New key foo (spn)
    if(!Pex::Utils::CheckKeys(
      $exploit->PayloadKeysParsed,
      $payload->Keys,
      $exploit->PayloadKeysType)) {

      $self->PrintDebugLine(3, $payload->SelfEndName . " failed key check");
      next CHECK;
    }
    
    if($exploit->Priv < $payload->Priv) {
      $self->PrintDebugLine(3, $payload->SelfEndName . " failed, payload needs more priviledge than exploit provides");
      next CHECK;
    }

    #fixme Eventually we should also factor in the Encoder Size, even though we will catch it in Encode
    if($exploit->PayloadSpace < $payload->Size) {
      $self->PrintDebugLine(3, $payload->SelfEndName . " failed, payload is too large for exploit, Exploit: " . $exploit->PayloadSpace . " Payload: " . $payload->Size);
      next CHECK;
    }

    $match->{$payloadName} = $payloads->{$payloadName};
  }
  return($match);
}

sub Encode {
  my $self = shift;
  my $exploit = $self->GetTempEnv('_Exploit');
  my $payload = $self->GetTempEnv('_Payload');

  my @nops = $self->GetNops;
  my @encoders = $self->GetEncoders;

  my $payloadArch = $payload->Arch;
  my $payloadOS = $payload->OS;

  my $badChars = $exploit->PayloadBadChars || '';
  my $prependEncoder = $exploit->PayloadPrependEncoder || '';
  my $exploitSpace = $exploit->PayloadSpace || '';
  my $encodedPayload;

  if(Pex::Text::BadCharCheck($badChars, $prependEncoder)) {
    # This should never happen unless the exploit coder is dumb, but might as well check
    $self->SetError('Bad Characters in prependEncoder');
    return;
  }

  foreach my $encoderName (@encoders) {
    $self->PrintDebugLine(1, "Trying encoder $encoderName");
    my $encoder = $self->MakeEncoder($encoderName);
    if(!$encoder) {
      $self->PrintDebugLine(1, "Failed to make encoder $encoderName");
      next;
    }
    my $encoderArch = $encoder->Arch;
    my $encoderOS = $encoder->OS;

    if(!$self->ListCheck($payloadArch, $encoderArch)) {
      $self->PrintDebugLine(2, "$encoderName failed, doesn't support all architectures");
      $self->PrintDebugLine(4, "payloadArch: " . join(',', @{$payloadArch}));
      $self->PrintDebugLine(4, "encoderArch: " . join(',', @{$encoderArch}));
      next;
    }
    if(!$self->ListCheck($payloadOS, $encoderOS)) {
      $self->PrintDebugLine(2, "$encoderName failed, doesn't support all operating systems");
      $self->PrintDebugLine(4, "payloadOS: " . join(',', @{$payloadOS}));
      $self->PrintDebugLine(4, "encoderOS: " . join(',', @{$encoderOS}));
      next;
    }
    if(!Pex::Utils::CheckKeys($exploit->EncoderKeys, $encoder->Keys, $exploit->EncoderKeysType)) {
      $self->PrintDebugLine(2, "$encoderName failed Keys check");
    }
    
    my $rawShell = $exploit->PayloadPrepend . $payload->Build . $exploit->PayloadAppend;
    my $encodedShell = $encoder->Encode($rawShell, $badChars);

    if(!$encodedShell) {
      $self->PrintDebugLine(1, "$encoderName failed to return an encoded payload");
      next;
    }

    if($encoder->IsError) {
      $self->PrintDebugLine(1, "$encoderName failed with an error");
      $self->PrintDebugLine(4, $encoder->GetError);
      $encoder->ClearError;
      next;
    }

    if(Pex::Text::BadCharCheck($badChars, $encodedShell)) {
      $self->PrintDebugLine(2, "$encoderName failed, bad chars in encoded payload");
      $self->PrintDebugLine(5, "encoded payload:");
      $self->PrintDebugLine(5, Pex::Text::BufferC($encodedShell));
      next;
    }

    $encodedShell = $prependEncoder . $encodedShell;
    
    if(length($encodedShell) > $exploitSpace - $exploit->PayloadMinNops) {
      $self->PrintDebugLine(2, "$encoderName failed, encoded payload too large for exploit");
      $self->PrintDebugLine(4, "ExploitSpace: $exploitSpace");
      $self->PrintDebugLine(4, "EncodedLength: " . length($encodedShell)); 
      $self->PrintDebugLine(4, 'MinNops: ' . $exploit->PayloadMinNops . ' MaxNops: ' . $exploit->PayloadMaxNops);
      next;
    }

    $encodedPayload = Msf::EncodedPayload->new($rawShell, $encodedShell);
    last;
  }

  if(!$encodedPayload) {
    $self->SetError("No encoders succeeded");
    return;
  }

  my $maxNops = defined($exploit->PayloadMaxNops) ? $exploit->PayloadMaxNops : 10000000;
  my $emptySpace = $exploitSpace - length($encodedPayload->EncodedPayload);
  my $nopSize = $maxNops < $emptySpace ? $maxNops : $emptySpace;
  my $success = 0;

  foreach my $nopName (@nops) {
    $self->PrintDebugLine(1, "Trying $nopName");
    my $nop = $self->MakeNop($nopName);
    if(!$nop) {
      $self->PrintDebugLine(1, "Failed to make nop generator $nop");
      next;
    }
    my $nopArch = $nop->Arch;
    my $nopOS = $nop->OS;

    if(!$self->ListCheck($payloadArch, $nopArch)) {
      $self->PrintDebugLine(2, "$nopName failed, doesn't support all architectures");
      $self->PrintDebugLine(4, "payloadArch: " . join(',', @{$payloadArch}));
      $self->PrintDebugLine(4, "nopArch: " . join(',', @{$nopArch}));
      next;
    }
    if(!$self->ListCheck($payloadOS, $nopOS)) {
      $self->PrintDebugLine(2, "$nopName failed, doesn't support all operating systems");
      $self->PrintDebugLine(4, "payloadOS: " . join(',', @{$payloadOS}));
      $self->PrintDebugLine(4, "nopOS: " . join(',', @{$nopOS}));
      next;
    }

    my $nops = $nop->Nops($nopSize, $badChars);

    if($nop->IsError) {
      $self->PrintDebugLine(1, "$nopName failed with an error");
      $self->PrintDebugLine(4, $nop->GetError);
      $nop->ClearError;
      next;
    }

    if(length($nops) != $nopSize) {
      $self->PrintDebugLine(2, "$nopName failed, error generating nops");
      $self->PrintDebugLine(5, 'length: ' . length($nops) . 'wanted: ' . $nopSize);
      next;
    }

    if(Pex::Text::BadCharCheck($badChars, $nops)) {
      $self->PrintDebugLine(2, "$nopName failed, bad chars in nops");
      next;
    }

    $success = 1;
    $encodedPayload->SetNops($nops);
    last;
  }

  if(!$success) {
    $self->SetError("No nop generators succeeded");
    return;
  }
#  $self->SetTempEnv('EncodedPayload', $encodedPayload);
  return($encodedPayload);
}

sub GetEncoders {
  my $self = shift;
  my @preferred;
  foreach my $encoder (split(',', $self->GetEnv('Encoder'))) {
    if(index($encoder, '::') == -1) {
      $encoder = 'Msf::Encoder::' . $encoder;
    }
    push(@preferred, $encoder);
  }
  return(@preferred) if($self->GetEnv('EncoderDontFallThrough'));
  my @encoders;
  foreach my $encoder (keys(%{$self->GetTempEnv('_Encoders')})) {
    next if(scalar(grep { $_ eq $encoder } @preferred));
    push(@encoders, $encoder);
  }
  return(@preferred, @encoders);
}
sub GetNops {
  my $self = shift;
  my @preferred;
  foreach my $nop (split(',', $self->GetEnv('Nop'))) {
    if(index($nop, '::') == -1) {
      $nop = 'Msf::Nop::' . $nop;
    }
    push(@preferred, $nop);
  }
  return(@preferred) if($self->GetEnv('NopDontFallThrough'));
  my @nops;
  foreach my $nop (keys(%{$self->GetTempEnv('_Nops')})) {
    next if(scalar(grep { $_ eq $nop } @preferred));
    push(@nops, $nop);
  }
  return(@preferred, @nops);
}
sub MakeEncoder {
  my $self = shift;
  my $name = shift;
  # Check to see if the encoder is in our encoders list
  return if(!scalar(grep { $_ eq $name } keys(%{$self->GetTempEnv('_Encoders')})));

  my $encoder = $name->new;
  return($encoder);
}
sub MakeNop {
  my $self = shift;
  my $name = shift;
  # Check to see if the encoder is in our nops list
  return if(!scalar(grep { $_ eq $name } keys(%{$self->GetTempEnv('_Nops')})));

  my $nop = $name->new;
  return($nop);
}

# Example usage: ListCheck($exploitArch, $encoderArch)
# All of list1 must be in list2 unless list2 is empty
sub ListCheck {
  my $self = shift;
  my $list1 = shift || [ ];
  my $list2 = shift || [ ];

  return(1) if(!@{$list2});
  return(Pex::Utils::ArrayContainsAll($list2, $list1));
}

sub SaveConfig {
  my $self = shift;
  Msf::Config->SaveConfig($self->ConfigFile);
}

sub ActiveStateSucks {
    return if $^O ne 'MSWin32';
    
    print 
    q|

   *** ACTIVESTATE PERL IS NOT SUPPPORTED ***

If you would like to use the Metasploit Framework
under the Windows platform, please install Cygwin.
Cygwin is a free Unix emulation environment, you
can obtain a copy online at the following address:

http://www.cygwin.com/

Please see docs/QUICKSTART.cygwin for more info.

|;
    exit(0);
}

1;
