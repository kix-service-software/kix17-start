# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::KIXSidebarRemoteDB;

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

sub KIXSidebarRemoteDBSearch {
    my ( $Self, %Param ) = @_;

    # check needed params
    foreach (
        qw(
        DatabaseDSN DatabaseUser
        DatabaseTable ShowAttributes
        SearchAttribute SearchValue
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

    $Kernel::OM->ObjectParamAdd(
        'Kernel::System::KIXSBRemoteDB' => {
            DatabaseDSN   => $Param{DatabaseDSN},
            DatabaseUser  => $Param{DatabaseUser},
            DatabasePw    => $Param{DatabasePw} || '',
            CaseSensitive => $Param{DatabaseCaseSensitive} || '',
            Type          => $Param{DatabaseType},
        },
    );
    my $KIXSBRemoteDBObject = $Kernel::OM->Get('Kernel::System::KIXSBRemoteDB');

    my @List;

    my @RestrictedMandatory = ();
    if (
        $Param{RestrictedMandatory}
        && ref($Param{RestrictedMandatory}) eq 'ARRAY'
    ) {
        push( @RestrictedMandatory, @{ $Param{RestrictedMandatory} } );
    }
    my @RestrictedAttributes = ();
    if (
        $Param{RestrictedAttributes}
        && ref($Param{RestrictedAttributes}) eq 'ARRAY'
    ) {
        push( @RestrictedAttributes, @{ $Param{RestrictedAttributes} } );
    }
    my @RestrictedValues = ();
    if (
        $Param{RestrictedValues}
        && ref($Param{RestrictedValues}) eq 'ARRAY'
    ) {
        push( @RestrictedValues, @{ $Param{RestrictedValues} } );
    }

    # check restricted configurtion
    if (
        @RestrictedMandatory
        && @RestrictedAttributes
        && @RestrictedValues
        && scalar(@RestrictedMandatory) == scalar(@RestrictedValues)
        && scalar(@RestrictedAttributes) == scalar(@RestrictedValues)
        )
    {
        for (my $Index = 0; $Index < scalar(@RestrictedAttributes); $Index++) {
            if (
                $RestrictedMandatory[$Index]
                && !$RestrictedValues[$Index]
                )
            {
                return \@List;
            }
        }
    }

    my $QuotedValue = $KIXSBRemoteDBObject->Quote( $Param{SearchValue} );

    my $QueryCondition = $KIXSBRemoteDBObject->QueryCondition(
        Key          => $Param{SearchAttribute},
        Value        => $QuotedValue,
        SearchPrefix => '*',
        SearchSuffix => '*',
    );

    # attach restricted config
    if (
        @RestrictedAttributes
        && @RestrictedValues
        && scalar(@RestrictedAttributes) == scalar(@RestrictedValues)
        )
    {
        for (my $Index = 0; $Index < scalar(@RestrictedAttributes); $Index++) {
            if ($RestrictedValues[$Index]) {
                $QueryCondition .= ' AND ('
                                . $RestrictedAttributes[$Index]
                                . '=\'';
                # check if value is a array ref to handle
                if ( ref($RestrictedValues[$Index]) eq 'ARRAY' ) {
                    # quote every entry
                    foreach my $Entry (@{$RestrictedValues[$Index]}) {
                        $Entry = $KIXSBRemoteDBObject->Quote($Entry);
                    }

                    # No handling specified or OR
                    if (
                        !$Param{RestrictedArrayHandling}
                        || $Param{RestrictedArrayHandling} =~ m/OR/i
                    ) {
                        $QueryCondition .= join('\' OR ' . $RestrictedAttributes[$Index] . '=\'', @{$RestrictedValues[$Index]});
                    }
                    # handling AND
                    elsif ( $Param{RestrictedArrayHandling} =~ m/AND/i ) {
                        $QueryCondition .= join('\' AND ' . $RestrictedAttributes[$Index] . '=\'', @{$RestrictedValues[$Index]});
                    }
                    # handling FIRST
                    elsif ( $Param{RestrictedArrayHandling} =~ m/FIRST/i ) {
                        $QueryCondition .= $RestrictedValues[$Index]->[0];
                    }
                    # handling LAST
                    elsif ( $Param{RestrictedArrayHandling} =~ m/LAST/i ) {
                        $QueryCondition .= $RestrictedValues[$Index]->[-1];
                    }
                    # fallback to OR
                    else {
                        $QueryCondition .= join('\' OR ' . $RestrictedAttributes[$Index] . '=\'', @{$RestrictedValues[$Index]});
                    }
                } else {
                    $QueryCondition .= $KIXSBRemoteDBObject->Quote($RestrictedValues[$Index])
                }

                $QueryCondition .= '\')';
            }
        }
    }

    my $SelectString = '';
    if ( $Param{IdentifierAttribute} ) {
        $SelectString = $Param{IdentifierAttribute};
    }
    if ( $Param{DynamicFieldAttributes} ) {
        if ( $SelectString ) {
            $SelectString .= ',';
        }
        $SelectString .= $Param{DynamicFieldAttributes};
    }
    if ( $Param{PopupAttributes} ) {
        if ( $SelectString ) {
            $SelectString .= ',';
        }
        $SelectString .= $Param{PopupAttributes};
    }
    if ( $SelectString ) {
        $SelectString .= ',';
    }
    $SelectString .= $Param{ShowAttributes};

    # build SQL
    my $SQL = 'SELECT '
        . $SelectString
        . ' FROM '
        . $Param{DatabaseTable};
    if ($QueryCondition ne '()') {
        $SQL .= ' WHERE '
             . $QueryCondition;
    }

    # check cache
    if ( $Param{DatabaseCacheTTL} ) {
        $Self->{CacheObject} = $Kernel::OM->Get('Kernel::System::Cache');

        # set CacheType and CacheKey
        $Self->{CacheType} = "KIXSidebarRemoteDB";
        $Self->{CacheKey}  = "Results::" . $Param{DatabaseDSN} . "::" . $SQL;

        my $List = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => $Self->{CacheKey},
        );
        return \@{$List} if $List;
    }

    my $Success = $KIXSBRemoteDBObject->Prepare(
        SQL => $SQL,
    );
    if ( !$Success ) {
        return;
    }

    # fetch result
    while (my @Row = $KIXSBRemoteDBObject->FetchrowArray()) {
        push( @List, \@Row );

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

    return \@List;
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
