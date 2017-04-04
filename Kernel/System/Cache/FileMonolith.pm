# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Cache::FileMonolith;

use strict;
use warnings;
use File::stat;
use Storable qw(lock_store lock_retrieve);

use Kernel::System::VariableCheck qw(:all);

umask 002;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Main',
);

use vars qw(@ISA);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

	$Self->{MainObject} = $Kernel::OM->Get('Kernel::System::Main');

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $TempDir = $ConfigObject->Get('TempDir');
    $Self->{CacheDirectory} = $TempDir . '/CacheFileMonolith';

    # check if cache directory exists and in case create one
    for my $Directory ( $TempDir, $Self->{CacheDirectory} ) {
        if ( !-e $Directory ) {
            ## no critic
            if ( !mkdir( $Directory, 0770 ) ) {
                ## use critic
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Can't create directory '$Directory': $!",
                );
            }
        }
    }
	
	# init RAM cache
	$Self->{Cache} = {};

    return $Self;
}

sub Set {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type Key Value TTL)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # read the file (if necessary)
    my $Result = $Self->_FileRead(
        Type => $Param{Type},
    );
    return if !IsHashRefWithData($Self->{Cache}->{$Param{Type}});

    my $TTL = time() + $Param{TTL};     # do not move this into the hash below, since this will result in about 5000 Ops/s less
	$Self->{Cache}->{$Param{Type}}->{IsDirty} = 1;
	$Self->{Cache}->{$Param{Type}}->{Content}->{$Param{Key}} = {
		Value => $Param{Value},
		TTL   => $TTL,
	};
	
	return 1;
}

sub Get {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Key)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # read the file (if necessary)
	my $Result = $Self->_FileRead(
		Type => $Param{Type},
	);
    return if !IsHashRefWithData($Self->{Cache}->{$Param{Type}}->{Content});

    # check TTL
    if ($Self->{Cache}->{$Param{Type}}->{Content}->{$Param{Key}}->{TTL} && $Self->{Cache}->{$Param{Type}}->{Content}->{$Param{Key}}->{TTL} < time()) {
        delete $Self->{Cache}->{$Param{Type}}->{Content}->{$Param{Key}};
    }

	if (IsHashRefWithData($Self->{Cache}->{$Param{Type}}->{Content}->{$Param{Key}})) {
	    return $Self->{Cache}->{$Param{Type}}->{Content}->{$Param{Key}}->{Value};
	}
	
	return;
}

sub Delete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Key)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # read the file (if necessary)
	my $Result = $Self->_FileRead(
		Type => $Param{Type},
	);
	return if !IsHashRefWithData($Self->{Cache}->{$Param{Type}});

    delete $Self->{Cache}->{$Param{Type}}->{Content}->{$Param{Key}};
}

sub CleanUp {
    my ( $Self, %Param ) = @_;

	# get main object
	my @FileList = $Self->{MainObject}->DirectoryRead(
		Directory => $Self->{CacheDirectory},
		Filter    => $Param{Type} || '*',
	);
	
	foreach my $File (@FileList) {
		$Self->{MainObject}->FileDelete(
			Directory => $Self->{CacheDirectory},
			Filename  => $Param{Type},
		);
	}
}

sub _FileRead {
    my ( $Self, %Param ) = @_;

    
    # check and retrieve file if exists and the memory cache has not been loaded for this this or the file on the disk has been modified in the meantime
    my $CacheFile = "$Self->{CacheDirectory}/$Param{Type}";
    if (-f $CacheFile && (!$Self->{Cache}->{$Param{Type}} || $Self->{Cache}->{$Param{Type}}->{FileMTime} < (stat($CacheFile))[9])) {

        $Self->{Cache}->{$Param{Type}}->{IsDirty} = 0;
        $Self->{Cache}->{$Param{Type}}->{FileMTime} = (stat($CacheFile))[9];
        $Self->{Cache}->{$Param{Type}}->{Content} = lock_retrieve($CacheFile); 
    }

	return 1;
}

sub DESTROY {
    my $Self = shift;

	# write all dirty types to file
	foreach my $Type (keys %{$Self->{Cache}}) {
		next if !$Self->{Cache}->{$Type}->{IsDirty};
		
		# store data to file
        lock_store($Self->{Cache}->{$Type}->{Content}, "$Self->{CacheDirectory}/$Type");
   	}

    return 1;
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
