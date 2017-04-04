# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::CIClassReference;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMCIAttributCollectionUtils',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Log'
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::CIClassReference - xml backend module

=head1 SYNOPSIS

All xml functions of CIClassReference objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem::XML::Type::CIClassReference');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{GeneralCatalogObject} = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    $Self->{CIACUtilsObject}      = $Kernel::OM->Get('Kernel::System::ITSMCIAttributCollectionUtils');
    $Self->{ConfigItemObject}     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    $Self->{LogObject}            = $Kernel::OM->Get('Kernel::System::Log');

    return $Self;
}

=item ValueLookup()

get the xml data of a version

    my $Value = $BackendObject->ValueLookup(
        Value => 11, # (optional)
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    return '' if !$Param{Value};

    my $CIVersionDataRef = $Self->{ConfigItemObject}->VersionGet(
        ConfigItemID => $Param{Value},
        XMLDataGet   => 0,
    );
    my $CIName = $Param{Value};

    if (
        $CIVersionDataRef
        &&
        ( ref($CIVersionDataRef) eq 'HASH' ) &&
        $CIVersionDataRef->{Name}
        )
    {
        $CIName = $CIVersionDataRef->{Name}
            . " ("
            . $CIVersionDataRef->{Number}
            . ")";
    }

    return $CIName;
}

=item StatsAttributeCreate()

create a attribute array for the stats framework

    my $Attribute = $BackendObject->StatsAttributeCreate(
        Key => 'Key::Subkey',
        Name => 'Name',
        Item => $ItemRef,
    );

=cut

sub StatsAttributeCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Name Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # create arrtibute
    my $Attribute = [
        {
            Name             => $Param{Name},
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => $Param{Key},
            Block            => 'InputField',
        },
    ];

    return $Attribute;
}

=item ExportSearchValuePrepare()

prepare search value for export

    my $ArrayRef = $BackendObject->ExportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    # lookup CI number for given CI ID
    my $CIRef = $Self->{ConfigItemObject}->ConfigItemGet(
        ConfigItemID => $Param{Value},
    );
    if ( $CIRef && ref $CIRef eq 'HASH' && $CIRef->{Number} ) {
        return $CIRef->{Number};
    }

    return '';
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    my $SearchAttr = $Param{Item}->{Input}->{ReferencedCIClassReferenceAttributeKey} || '';

    if ($SearchAttr) {

        my $VersionData = $Self->{ConfigItemObject}->VersionGet(
            ConfigItemID => $Param{Value},
        );

        if ( $VersionData && ref $VersionData eq 'HASH' ) {

            # get ConfigItem class ID
            my $ReferencedCIClassID = "";
            if (
                $Param{Item}
                && ref( $Param{Item} ) eq 'HASH'
                && $Param{Item}->{Input}
                && ref( $Param{Item}->{Input} ) eq 'HASH'
                && $Param{Item}->{Input}->{ReferencedCIClassName}
                )
            {
                my $ItemDataRef = $Self->{GeneralCatalogObject}->ItemGet(
                    Class => 'ITSM::ConfigItem::Class',
                    Name => $Param{Item}->{Input}->{ReferencedCIClassName} || '',
                );
                if ( $ItemDataRef && ref($ItemDataRef) eq 'HASH' && $ItemDataRef->{ItemID} ) {
                    $ReferencedCIClassID = $ItemDataRef->{ItemID} || '';
                }

                my $XMLDefinition =
                    $Self->{ConfigItemObject}->DefinitionGet( ClassID => $ReferencedCIClassID, );

                my $ArrRef = $Self->{CIACUtilsObject}->GetAttributeValuesByKey(
                    KeyName       => $SearchAttr,
                    XMLData       => $VersionData->{XMLData}->[1]->{Version}->[1],
                    XMLDefinition => $XMLDefinition->{DefinitionRef},
                );

                if ( $ArrRef && $ArrRef->[0] ) {
                    return $ArrRef->[0];
                }
            }
        }
    }

    # lookup CI number for given CI ID
    my $CIRef = $Self->{ConfigItemObject}->ConfigItemGet(
        ConfigItemID => $Param{Value},
    );
    if ( $CIRef && ref $CIRef eq 'HASH' && $CIRef->{Number} ) {
        return $CIRef->{Number};
    }

    return '';
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    # check if CI number was given
    my $CIID = $Self->{ConfigItemObject}->ConfigItemLookup(
        ConfigItemNumber => $Param{Value},
    );
    return $CIID if $CIID;

    # check if given value is a valid CI ID
    if ( $Param{Value} !~ /\D/ ) {
        my $CINumber = $Self->{ConfigItemObject}->ConfigItemLookup(
            ConfigItemID => $Param{Value},
        );
        return $Param{Value} if $CINumber;
    }

    return '';
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    my $SearchAttr = $Param{Item}->{Input}->{ReferencedCIClassReferenceAttributeKey} || '';

    # make CI-Number out of given value
    if ($SearchAttr) {

        # get ConfigItem class ID
        my $ReferencedCIClassID = "";
        if (
            $Param{Item}
            && ref( $Param{Item} ) eq 'HASH'
            && $Param{Item}->{Input}
            && ref( $Param{Item}->{Input} ) eq 'HASH'
            && $Param{Item}->{Input}->{ReferencedCIClassName}
            )
        {
            my $ItemDataRef = $Self->{GeneralCatalogObject}->ItemGet(
                Class => 'ITSM::ConfigItem::Class',
                Name => $Param{Item}->{Input}->{ReferencedCIClassName} || '',
            );
            if ( $ItemDataRef && ref($ItemDataRef) eq 'HASH' && $ItemDataRef->{ItemID} ) {
                $ReferencedCIClassID = $ItemDataRef->{ItemID} || '';
            }

            # prepare search params
            my %SearchParams = ();
            my %SearchData   = ();

            $SearchData{$SearchAttr} = $Param{Value};

            my $XMLDefinition =
                $Self->{ConfigItemObject}->DefinitionGet( ClassID => $ReferencedCIClassID, );

            my @SearchParamsWhat;
            $Self->_XMLSearchDataPrepare(
                XMLDefinition => $XMLDefinition->{DefinitionRef},
                What          => \@SearchParamsWhat,
                SearchData    => \%SearchData,
            );

            if (@SearchParamsWhat) {
                $SearchParams{What} = \@SearchParamsWhat;
            }

            # search the config items
            my $ConfigItemIDs = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
                %SearchParams,
                ClassIDs              => [$ReferencedCIClassID],
                PreviousVersionSearch => 0,
            );

            # get and return CofigItem ID
            my $CIID = "";
            if ( $ConfigItemIDs && ref($ConfigItemIDs) eq 'ARRAY' ) {
                $CIID = $ConfigItemIDs->[0] || '';
            }
            return $CIID;
        }
    }

    # check if CI number was given
    my $CIID = $Self->{ConfigItemObject}->ConfigItemLookup(
        ConfigItemNumber => $Param{Value},
    );
    return $CIID if $CIID;

    # make CI-Number out of given Name...
    my $ReferencedCIClassID = "";
    if (
        $Param{Item}
        && ref( $Param{Item} ) eq 'HASH'
        && $Param{Item}->{Input}
        && ref( $Param{Item}->{Input} ) eq 'HASH'
        && $Param{Item}->{Input}->{ReferencedCIClassName}
        )
    {
        my $RefClassName = $Param{Item}->{Input}->{ReferencedCIClassName};
        my $ItemDataRef  = $Self->{GeneralCatalogObject}->ItemGet(
            Class => 'ITSM::ConfigItem::Class',
            Name => $Param{Item}->{Input}->{ReferencedCIClassName} || '',
        );
        if ( $ItemDataRef && ref($ItemDataRef) eq 'HASH' && $ItemDataRef->{ItemID} ) {
            $ReferencedCIClassID = $ItemDataRef->{ItemID} || '';
        }
        my $ConfigItemIDs = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
            Name     => $Param{Value},
            ClassIDs => [$ReferencedCIClassID],
        );
        my $CIID = "";
        if ( $ConfigItemIDs && ref($ConfigItemIDs) eq 'ARRAY' ) {
            $CIID = $ConfigItemIDs->[0] || '';
        }
        return $CIID if $CIID;
    }

    # check if given value is a valid CI ID
    if ( $Param{Value} !~ /\D/ ) {
        my $CINumber = $Self->{ConfigItemObject}->ConfigItemLookup(
            ConfigItemID => $Param{Value},
        );
        return $Param{Value} if $CINumber;
    }

    return '';
}

sub _XMLSearchDataPrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition} || ref $Param{XMLDefinition} ne 'ARRAY';
    return if !$Param{What}          || ref $Param{What}          ne 'ARRAY';
    return if !$Param{SearchData}    || ref $Param{SearchData}    ne 'HASH';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # create key
        my $Key =
            $Param{Prefix} ? $Param{Prefix} . '::' . $Item->{Key} : $Item->{Key};

        if ( $Param{SearchData}->{$Key} ) {

            # create search key
            my $SearchKey = $Key;
            $SearchKey =~ s{ :: }{\'\}[%]\{\'}xmsg;

            # create search hash
            my $SearchHash =
                {
                '[1]{\'Version\'}[1]{\''
                    . $SearchKey
                    . '\'}[%]{\'Content\'}' => $Param{SearchData}->{$Key},
                };
            push @{ $Param{What} }, $SearchHash;
        }
        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_XMLSearchDataPrepare(
            XMLDefinition => $Item->{Sub},
            What          => $Param{What},
            SearchData    => $Param{SearchData},
            Prefix        => $Key,
        );
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
