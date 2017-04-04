# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMCIAttributCollectionUtils;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::ITSMConfigItem'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object...
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigItemObject} = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    return $Self;
}

#-------------------------------------------------------------------------------
# capeIT
# Thefollowing methods are meant to ease the handling of the XML-LIKE data hash.
# They do not replace any internal/original methods.

=item GetAttributeValuesByKey()

    Returns values first found, for a given attribute key.
        _GetAttributeValuesByKey (
            KeyName       => 'FQDN',
            XMLData       => $XMLDataRef,
            XMLDefinition => $XMLDefRef,
        );
=cut

sub GetAttributeValuesByKey {
    my ( $Self, %Param ) = @_;
    my @RetArray = qw{};

    # check required params...
    if (
        !$Param{KeyName}
        ||
        ( !$Param{XMLData} ) ||
        ( !$Param{XMLDefinition} ) ||
        ( ref $Param{XMLData} ne 'HASH' ) ||
        ( ref $Param{XMLDefinition} ne 'ARRAY' )
        )
    {
        return \@RetArray;
    }

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # no content then stop loop...
            last COUNTER if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

            # check if we are looking for this key
            if ( $Item->{Key} eq $Param{KeyName} ) {

                # get the value...
                my $Value = $Self->{ConfigItemObject}->XMLValueLookup(
                    Item  => $Item,
                    Value => length( $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content} )
                    ? $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content}
                    : '',
                );

                if ($Value) {
                    push( @RetArray, $Value );
                }
            }

            next COUNTER if !$Item->{Sub};

            #recurse if subsection available...
            my $SubResult = $Self->GetAttributeValuesByKey(
                KeyName       => $Param{KeyName},
                XMLDefinition => $Item->{Sub},
                XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
            );

            if ( ref($SubResult) eq 'ARRAY' ) {
                for my $ArrayElem ( @{$SubResult} ) {
                    push( @RetArray, $ArrayElem );
                }
            }
        }
    }

    return \@RetArray;
}

=item GetAttributeContentsByKey()

    Returns contents first found, for a given attribute key.
        GetAttributeContentsByKey (
            KeyName       => 'FQDN',
            XMLData       => $XMLDataRef,
            XMLDefinition => $XMLDefRef,
        );
=cut

sub GetAttributeContentsByKey {
    my ( $Self, %Param ) = @_;
    my @RetArray = qw{};

    # check required params...
    if (
        !$Param{KeyName}
        ||
        ( !$Param{XMLData} ) ||
        ( !$Param{XMLDefinition} ) ||
        ( ref $Param{XMLData} ne 'HASH' ) ||
        ( ref $Param{XMLDefinition} ne 'ARRAY' )
        )
    {
        return \@RetArray;
    }

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # no content then stop loop...
            last COUNTER if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

            # get the value...
            my $Content
                = length( $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content} )
                ? $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content}
                : '';

            if ( ( $Item->{Key} eq $Param{KeyName} ) && $Content ) {
                push( @RetArray, $Content );
            }

            next COUNTER if !$Item->{Sub};

            #recurse if subsection available...
            my $SubResult = $Self->GetAttributeContentsByKey(
                KeyName       => $Param{KeyName},
                XMLDefinition => $Item->{Sub},
                XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
            );

            if ( ref($SubResult) eq 'ARRAY' ) {
                for my $ArrayElem ( @{$SubResult} ) {
                    push( @RetArray, $ArrayElem );
                }
            }
        }
    }

    return \@RetArray;
}

=item GetAttributeDataByType()

    Returns a hashref with names and attribute values from the
    XML-DataHash for a specified data type.

    $ConfigItemObject->GetAttributeDataByType(
        XMLData       => $XMLData,
        XMLDefinition => $XMLDefinition,
        AttributeType => $AttributeType,
    );

=cut

sub GetAttributeDataByType {
    my ( $Self, %Param ) = @_;

    my @Keys = ();
    my %Result;

    #get all keys for specified input type...
    @Keys = @{
        $Self->GetKeyNamesByType(
            XMLDefinition => $Param{XMLDefinition},
            AttributeType => $Param{AttributeType}
            )
        };

    if ( $Param{Content} ) {
        for my $CurrKey (@Keys) {
            my $CurrContent = $Self->GetAttributeContentsByKey(
                KeyName       => $CurrKey,
                XMLData       => $Param{XMLData},
                XMLDefinition => $Param{XMLDefinition},
            );
            $Result{$CurrKey} = $CurrContent;
        }
    }
    else {
        for my $CurrKey (@Keys) {
            my $CurrVal = $Self->GetAttributeValuesByKey(
                KeyName       => $CurrKey,
                XMLData       => $Param{XMLData},
                XMLDefinition => $Param{XMLDefinition},
            );
            $Result{$CurrKey} = $CurrVal;
        }
    }

    return \%Result;

}

=item GetKeyNamesByType()

    Returns an array of keynames which are of a specified data type.

    $ConfigItemObject->GetKeyNamesByType(
        XMLDefinition => $XMLDefinition,
        AttributeType => $AttributeType,
    );

=cut

sub GetKeyNamesByType {
    my ( $Self, %Param ) = @_;

    my @Keys = ();
    my %Result;

    if ( defined( $Param{XMLDefinition} ) ) {

        for my $AttrDef ( @{ $Param{XMLDefinition} } ) {
            if ( $AttrDef->{Input}->{Type} eq $Param{AttributeType} ) {
                push( @Keys, $AttrDef->{Key} )
            }

            next if !$AttrDef->{Sub};

            my @SubResult = @{
                $Self->GetKeyNamesByType(
                    AttributeType => $Param{AttributeType},
                    XMLDefinition => $AttrDef->{Sub},
                    )
                };

            @Keys = ( @Keys, @SubResult );
        }

    }

    return \@Keys;
}

=item _GetKeyNamesByType()

    Sames as GetKeyNamesByType - returns an array of keynames which are of a
    specified data type. => use GetKeyNamesByType instead !
    !!! DEPRECATED - ONLY FOR COMPATIBILITY - WILL BE REMOVED !!!

    $ConfigItemObject->_GetKeyNamesByType(
        XMLDefinition => $XMLDefinition,
        AttributeType => $AttributeType,
    );

=cut

sub _GetKeyNamesByType {
    my ( $Self, %Param ) = @_;

    my @Keys = ();
    my %Result;

    if ( defined( $Param{XMLDefinition} ) ) {

        for my $AttrDef ( @{ $Param{XMLDefinition} } ) {
            if ( $AttrDef->{Input}->{Type} eq $Param{AttributeType} ) {
                push( @Keys, $AttrDef->{Key} )
            }

            next if !$AttrDef->{Sub};

            my @SubResult = @{
                $Self->_GetKeyNamesByType(
                    AttributeType => $Param{AttributeType},
                    XMLDefinition => $AttrDef->{Sub},
                    )
                };

            @Keys = ( @Keys, @SubResult );
        }

    }

    return \@Keys;
}

=item GetAttributeDefByTagKey()

Returns choosen CI attribute definition, for a given tag key.
    my %AttrDef = $ConfigItemObject->GetAttributeDefByTagKey (
        TagKey        => "[1]{'Version'}[1]{'Model'}[1]",
        XMLData       => $XMLDataRef,
        XMLDefinition => $XMLDefRef,
    );

returns

    Input => {
        Type
        Class
        Required
        Translation
        Size
        MaxLength
    }
    Key
    Name
    Searchable
    CountMin
    CountMax
    CountDefault

=cut

sub GetAttributeDefByTagKey {
    my ( $Self, %Param ) = @_;

    # check required params...
    return
        if (
        !$Param{XMLData}       || ref( $Param{XMLData} )       ne 'HASH' ||
        !$Param{XMLDefinition} || ref( $Param{XMLDefinition} ) ne 'ARRAY' ||
        !$Param{TagKey}
        );

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        next ITEM if ( !$Param{XMLData}->{ $Item->{Key} } );

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {
            if ( $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{TagKey} eq $Param{TagKey} ) {
                return \%{$Item};
            }

            next COUNTER if !$Item->{Sub};

            # recurse if subsection available...
            my $SubResult = $Self->GetAttributeDefByTagKey(
                TagKey        => $Param{TagKey},
                XMLDefinition => $Item->{Sub},
                XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
            );

            if ( $SubResult && ref($SubResult) eq 'HASH' ) {
                return \%{$SubResult};
            }
        }
    }

    return ();
}

=item VersionDataUpdate()

    Returns a the current version data in the most current definition format
    (usually this is done in the frontend). The version data might be structured
    in a previous definition.

    $NewVersionXMLData = $ConfigItemObject->VersionDataUpdate(
        XMLDefinition => $NewDefinitionRef->{DefinitionRef},
        XMLData       => $CurrentVersionRef->{XMLData}->[1]->{Version}->[1],
    );

=cut

sub VersionDataUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLData};
    return if ref $Param{XMLData} ne 'HASH';
    return if !$Param{XMLDefinition};
    return if ref $Param{XMLDefinition} ne 'ARRAY';

    my $FormData = {};

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        my $CounterInsert = 1;

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # create inputkey and addkey
            my $InputKey = $Item->{Key} . '::' . $Counter;
            if ( $Param{Prefix} ) {
                $InputKey = $Param{Prefix} . '::' . $InputKey;
            }

            #get content...
            my $Content = $Param{XMLData}->{ $Item->{Key} }->[1]->{Content} || '';

            # start recursion, if "Sub" was found
            if ( $Item->{Sub} ) {
                my $SubFormData = $Self->VersionDataUpdate(
                    XMLDefinition => $Item->{Sub},
                    XMLData       => $Param{XMLData}->{ $Item->{Key} }->[1],
                    Prefix        => $InputKey,
                );
                $FormData->{ $Item->{Key} }->[$CounterInsert] = $SubFormData;
            }

            $FormData->{ $Item->{Key} }->[$CounterInsert]->{Content} = $Content;
            $CounterInsert++;

        }
    }

    return $FormData;
}

=item SetAttributeContentsByKey()

    Sets the content of the specified keyname in the XML data hash.

    $ConfigItemObject->SetAttributeContentsByKey(
        KeyName       => 'Location',
        NewContent    => $RetireCILocationID,
        XMLData       => $NewVersionData,
        XMLDefinition => $UsedVersion,
    );

=cut

sub SetAttributeContentsByKey {
    my ( $Self, %Param ) = @_;

    # check required params...
    if (
        !$Param{KeyName}
        ||
        !length( $Param{NewContent} ) ||
        ( !$Param{XMLData} ) ||
        ( !$Param{XMLDefinition} ) ||
        ( ref $Param{XMLData} ne 'HASH' ) ||
        ( ref $Param{XMLDefinition} ne 'ARRAY' )
        )
    {
        return 0;
    }

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # no content then stop loop...
            last COUNTER if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

            # get the value...
            if ( $Item->{Key} eq $Param{KeyName} ) {
                $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content} = $Param{NewContent};
            }

            next COUNTER if !$Item->{Sub};

            #recurse if subsection available...
            my $SubResult = $Self->SetAttributeContentsByKey(
                KeyName       => $Param{KeyName},
                NewContent    => $Param{NewContent},
                XMLDefinition => $Item->{Sub},
                XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
            );

        }
    }

    return 0;
}

# EO capeIT
#-------------------------------------------------------------------------------

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
