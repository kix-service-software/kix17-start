# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
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
        && ( ref($CIVersionDataRef) eq 'HASH' )
        && $CIVersionDataRef->{Name}
    ) {
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
            XMLDataGet   => 1,
        );

        if ( $VersionData && ref $VersionData eq 'HASH' ) {
            return $VersionData->{Name} if $SearchAttr eq 'Name';

            my $XMLDefinition = $Self->{ConfigItemObject}->DefinitionGet( DefinitionID => $VersionData->{DefinitionID}, );

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
    else {
        # lookup CI number for given CI ID
        my $CIRef = $Self->{ConfigItemObject}->ConfigItemGet(
            ConfigItemID => $Param{Value},
        );
        if ( $CIRef && ref $CIRef eq 'HASH' && $CIRef->{Number} ) {
            return $CIRef->{Number};
        }
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

    # get class list
    my $ClassList = $Self->{GeneralCatalogObject}->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    # check for access rights on the classes
    for my $ClassID ( sort keys %{$ClassList} ) {
        my $HasAccess = $Self->{ConfigItemObject}->Permission(
            Type    => 'ro',
            Scope   => 'Class',
            ClassID => $ClassID,
            UserID  => $Self->{UserID} || 1,
        );

        delete $ClassList->{$ClassID} if !$HasAccess;
    }

    my @ClassIDArray = ();
    if ($Param{Item}->{Input}->{ReferencedCIClassID}) {
        if ($Param{Item}->{Input}->{ReferencedCIClassID} eq 'All') {
            @ClassIDArray = keys %{$ClassList};
        }
        else {
            my @TempClassIDArray = split( /\s*,\s*/, $Param{Item}->{Input}->{ReferencedCIClassID});
            for my $ClassID ( @TempClassIDArray ) {
                if ( $ClassList->{$ClassID} ) {
                    push( @ClassIDArray, $ClassID );
                }
            }
        }
    }
    elsif ($Param{Item}->{Input}->{ReferencedCIClassName}) {
        if ($Param{Item}->{Input}->{ReferencedCIClassName} eq 'All') {
            @ClassIDArray = keys %{$ClassList};
        }
        else {
            my @ClassNameArray = split( /\s*,\s*/, $Param{Item}->{Input}->{ReferencedCIClassName});
            CLASSNAME:
            for my $ClassName ( @ClassNameArray ) {
                if ( !$ClassName ) {
                    @ClassIDArray = ();
                    last CLASSNAME;
                }

                my $ItemDataRef = $Self->{GeneralCatalogObject}->ItemGet(
                    Class => 'ITSM::ConfigItem::Class',
                    Name  => $ClassName,
                );
                if (
                    $ItemDataRef
                    && ref($ItemDataRef) eq 'HASH'
                    && $ItemDataRef->{ItemID}
                    && $ClassList->{$ItemDataRef->{ItemID}}
                ) {
                    push( @ClassIDArray, $ItemDataRef->{ItemID} );
                }
                else {
                    @ClassIDArray = ();
                    last CLASSNAME;
                }
            }
        }
    }
    if ( !@ClassIDArray ) {
        push( @ClassIDArray, '0');
    }

    # make CI-ID out of given value
    if ($SearchAttr) {
        if ( $SearchAttr eq 'Name' ) {
            my $ConfigItemIDs = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
                Name     => $Param{Value},
                ClassIDs => \@ClassIDArray,
            );
            my $CIID = "";
            if ( $ConfigItemIDs && ref($ConfigItemIDs) eq 'ARRAY' ) {
                $CIID = $ConfigItemIDs->[0] || '';
            }
            return $CIID if $CIID;
        }
        else {
            # prepare search params
            my %SearchData   = (
                $SearchAttr => $Param{Value},
            );

            $SearchData{$SearchAttr} = $Param{Value};

            CLASSID:
            for my $ClassID ( @ClassIDArray ) {
                next CLASSID if ( !$ClassID );
                my $XMLDefinition = $Self->{ConfigItemObject}->DefinitionGet( ClassID => $ClassID, );

                my @SearchParamsWhat;
                $Self->_XMLSearchDataPrepare(
                    XMLDefinition => $XMLDefinition->{DefinitionRef},
                    What          => \@SearchParamsWhat,
                    SearchData    => \%SearchData,
                );

                my %SearchParams = ();
                if (@SearchParamsWhat) {
                    $SearchParams{What} = \@SearchParamsWhat;
                }

                # search the config items
                my $ConfigItemIDs = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
                    %SearchParams,
                    ClassIDs              => [$ClassID],
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
    }
    else {
        # check if CI number was given
        my $CIID = $Self->{ConfigItemObject}->ConfigItemLookup(
            ConfigItemNumber => $Param{Value},
        );
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
