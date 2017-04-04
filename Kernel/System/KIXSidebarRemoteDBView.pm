# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::KIXSidebarRemoteDBView;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::KIXSBRemoteDB',
    'Kernel::System::Log'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{LogObject} = $Kernel::OM->Get('Kernel::System::Log');

    return $Self;
}

sub KIXSidebarRemoteDBViewSearch {
    my ( $Self, %Param ) = @_;

    # check needed params
    foreach (
        qw(
        DatabaseDSN DatabaseUser
        DatabaseTable DatabaseFields
        DatabaseFieldKey Key
        )
        )
    {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    if ( ref( $Param{DatabaseFields} ) ne 'ARRAY' ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "DatabaseFields need to be an array!",
        );
        return;
    }

    $Kernel::OM->ObjectParamAdd(
        'Kernel::System::KIXSBRemoteDB' => {
            DatabaseDSN  => $Param{DatabaseDSN},
            DatabaseUser => $Param{DatabaseUser},
            DatabasePw   => $Param{DatabasePw} || '',
            Type         => $Param{DatabaseType},
        },
    );
    my $KIXSBRemoteDBObject = $Kernel::OM->Get('Kernel::System::KIXSBRemoteDB');

    # build SQL
    my $SQL = "SELECT "
        . join( ",", @{ $Param{DatabaseFields} } )
        . ' FROM '
        . $Param{DatabaseTable}
        . ' WHERE '
        . $Param{DatabaseFieldKey}
        . '=\'';

    # check if key is a array ref to handle
    if ( ref($Param{Key}) eq 'ARRAY' ) {
        # quote every entry
        foreach my $Entry (@{$Param{Key}}) {
            $Entry = $KIXSBRemoteDBObject->Quote($Entry);
        }

        # No handling specified or OR
        if (
            !$Param{DynamicFieldArrayHandling}
            || $Param{DynamicFieldArrayHandling} =~ m/OR/i
        ) {
            $SQL .= join('\' OR ' . $Param{DatabaseFieldKey} . '=\'', @{$Param{Key}});
        }
        # handling AND
        elsif ( $Param{DynamicFieldArrayHandling} =~ m/AND/i ) {
            $SQL .= join('\' AND ' . $Param{DatabaseFieldKey} . '=\'', @{$Param{Key}});
        }
        # handling FIRST
        elsif ( $Param{DynamicFieldArrayHandling} =~ m/FIRST/i ) {
            $SQL .= $Param{Key}->[0];
        }
        # handling LAST
        elsif ( $Param{DynamicFieldArrayHandling} =~ m/LAST/i ) {
            $SQL .= $Param{Key}->[-1];
        }
        # fallback to OR
        else {
            $SQL .= join('\' OR ' . $Param{DatabaseFieldKey} . '=\'', @{$Param{Key}});
        }
    } else {
        $SQL .= $KIXSBRemoteDBObject->Quote($Param{Key});
    }

    $SQL .= '\'';

    # check cache
    if ( $Param{DatabaseCacheTTL} ) {
        $Self->{CacheObject} = $Kernel::OM->Get('Kernel::System::Cache');

        # set CacheType and CacheKey
        $Self->{CacheType} = "KIXSidebarRemoteDBView";
        $Self->{CacheKey}  = "Results::" . $Param{DatabaseDSN} . "::" . $SQL;

        my $List = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => $Self->{CacheKey},
        );
        return \@{$List} if $List;
    }

    my $Success = $KIXSBRemoteDBObject->Prepare(
        SQL   => $SQL,
    );
    if ( !$Success ) {
        return;
    }

    my @List;
    while (my @Row = $KIXSBRemoteDBObject->FetchrowArray()) {
        my %Entry;
        for ( my $index = 0; $index < ( scalar @{ $Param{DatabaseFields} } ); $index++ ) {
            $Entry{ $Param{DatabaseFields}->[$index] } = ( defined( $Row[$index] ) ) ? $Row[$index] : '';
        }
        push ( @List, \%Entry );

        # Check if limit is reached
        last if ( $Param{Limit} && ( scalar @List ) == $Param{Limit} );
    }

    # cache request
    if ( $Param{DatabaseCacheTTL} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => $Self->{CacheKey},
            Value => \@List,
            TTL   => $Param{DatabaseCacheTTL},
        );
    }

    if ( scalar( @List ) ) {
        return \@List;
    }
    else {
        return;
    }
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
