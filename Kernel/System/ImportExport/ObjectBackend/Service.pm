# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::Service;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DynamicField',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ImportExport',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Package',
    'Kernel::System::Queue',
    'Kernel::System::Service',
    'Kernel::System::Type',
    'Kernel::System::User',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::ImportExport::ObjectBackend::Service - import/export backend for Service

=head1 SYNOPSIS

All functions to import and export Service entries

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('Kernel::System::ImportExport::ObjectBackend::Service');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get service type list
    $Self->{ServiceTypeList} = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'ITSM::Service::Type',
    );
    my %TmpHash = reverse( %{ $Self->{ServiceTypeList} } );
    $Self->{ReverseServiceTypeList} = \%TmpHash;

    # get criticality list
    my $ITSMCriticality = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
        Name => 'ITSMCriticality',
    );
    if (   $ITSMCriticality
        && $ITSMCriticality->{'FieldType'}  eq 'Dropdown'
        && $ITSMCriticality->{'ObjectType'} eq 'Ticket' )
    {
        $Self->{CriticalityList} = $ITSMCriticality->{'Config'}->{'PossibleValues'};
        my %TmpHash2 = reverse( %{ $Self->{CriticalityList} } );
        $Self->{ReverseCriticalityList} = \%TmpHash2;
    }

    return $Self;
}

=item ObjectAttributesGet()

get the object attributes of an object as array/hash reference

    my $Attributes = $ObjectBackend->ObjectAttributesGet(
        UserID => 1,
    );

=cut

sub ObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed object
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log( Priority => 'error', Message => 'Need UserID!' );
        return;
    }
    my %Validlist  = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();
    my $Attributes = [
        {
            Key   => 'DefaultValid',
            Name  => 'Default Validity',
            Input => {
                Type         => 'Selection',
                Data         => \%Validlist,
                Required     => 1,
                Translation  => 1,
                PossibleNone => 0,
                ValueDefault => 1,
            },
        },
    ];
    if ( $Self->{ServiceTypeList} ) {
        my $ServiceTypeDefault = {
            Key   => 'DefaultServiceTypeID',
            Name  => 'Default Service Type',
            Input => {
                Type         => 'Selection',
                Data         => $Self->{ServiceTypeList},
                Required     => 1,
                Translation  => 0,
                PossibleNone => 0,
            },
        };
        push( @{$Attributes}, $ServiceTypeDefault );
    }
    if ( $Self->{CriticalityList} ) {
        my $CriticalityDefault = {
            Key   => 'DefaultCriticalityID',
            Name  => 'Default Criticality',
            Input => {
                Type         => 'Selection',
                Data         => $Self->{CriticalityList},
                Required     => 1,
                Translation  => 0,
                PossibleNone => 0,
            },
        };
        push( @{$Attributes}, $CriticalityDefault );
    }
    return $Attributes;
}

=item MappingObjectAttributesGet()

get the mapping attributes of an object as array/hash reference

    my $Attributes = $ObjectBackend->MappingObjectAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub MappingObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('Kernel::System::ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );
    my $ElementList = [
        {
            Key   => 'ServiceID',
            Value => 'Service ID',
        },
        {
            Key   => 'Name',
            Value => 'Full Service Name',
        },
        {
            Key   => 'NameShort',
            Value => 'Short Service Name',
        },
        {
            Key   => 'Valid',
            Value => 'Validity',
        },
        {
            Key   => 'Comment',
            Value => 'Comment',
        },
    ];

    #---------------------------------------------------------------------------
    # get preferences...
    my %Preferences = ();
    if ( $Kernel::OM->Get('Kernel::Config')->Get('ServicePreferences') ) {
        %Preferences = %{ $Kernel::OM->Get('Kernel::Config')->Get('ServicePreferences') };
    }
    for my $Item ( sort keys %Preferences ) {
        if (
            $Preferences{$Item}->{SelectionSource}
            && $Preferences{$Item}->{PrefKey} =~ /^(.+)ID$/
            )
        {
            my $NamePart = $1;
            push(
                @{$ElementList},
                { Key => $NamePart, Value => $Preferences{$Item}->{Label} }
            );
        }

        if ( $Preferences{$Item}->{PrefKey} =~ /^(.+)ID$/ ) {
            my $NamePart = $1;
            push(
                @{$ElementList},
                {
                    Key   => $Preferences{$Item}->{PrefKey},
                    Value => $Preferences{$Item}->{Label} . " (ID)"
                }
            );
        }
        else {
            push(
                @{$ElementList},
                { Key => $Preferences{$Item}->{PrefKey}, Value => $Preferences{$Item}->{Label} }
            );
        }

    }

    #---------------------------------------------------------------------------
    # using ciritcality/servicetype-list as indicator
    if ( $Self->{CriticalityList} && $Self->{ServiceTypeList} ) {
        my $ElementListITSM = [
            {
                Key   => 'Type',
                Value => 'Service Type',
            },
            {
                Key   => 'Criticality',
                Value => 'Criticality',
            },
            {
                Key   => 'CurInciState',
                Value => 'Current Incident State',
            },
            {
                Key   => 'CurInciStateType',
                Value => 'Current Incident State Type',
            },
        ];
        my @TmpArray = ( @{$ElementList}, @{$ElementListITSM} );
        $ElementList = \@TmpArray;
    }
    my $Attributes = [
        {
            Key   => 'Key',
            Name  => 'Key',
            Input => {
                Type         => 'Selection',
                Data         => $ElementList,
                Required     => 1,
                Translation  => 1,
                PossibleNone => 1,
            },
        },
        {
            Key   => 'Identifier',
            Name  => 'Identifier',
            Input => { Type => 'Checkbox', },
        },
    ];

    return $Attributes;
}

=item SearchAttributesGet()

get the search object attributes of an object as array/hash reference

    my $AttributeList = $ObjectBackend->SearchAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub SearchAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }
    my $AttributeList = [
        {
            Key   => 'ServiceName',
            Name  => 'Service Name',
            Input => {
                Type      => 'Text',
                Size      => 80,
                MaxLength => 255,
            },
        },
    ];
    return $AttributeList;
}

=item ExportDataGet()

get export data as 2D-array-hash reference

    my $ExportData = $ObjectBackend->ExportDataGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub ExportDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('Kernel::System::ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check object data
    if ( !$ObjectData || ref $ObjectData ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No object data found for the template id $Param{TemplateID}",
        );
        return;
    }

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('Kernel::System::ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check the mapping list
    if ( !$MappingList || ref $MappingList ne 'ARRAY' || !@{$MappingList} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No valid mapping list found for the template id $Param{TemplateID}",
        );
        return;
    }

    # create the mapping object list
    my @MappingObjectList;
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData =
            $Kernel::OM->Get('Kernel::System::ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
            );

        # check mapping object data
        if ( !$MappingObjectData || ref $MappingObjectData ne 'HASH' ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No valid mapping list found for the template id $Param{TemplateID}",
            );
            return;
        }
        push( @MappingObjectList, $MappingObjectData );
    }

    # get search data
    my $SearchData = $Kernel::OM->Get('Kernel::System::ImportExport')->SearchDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );
    if ( $SearchData && ref($SearchData) ne 'HASH' ) {
        $SearchData = 0;
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message =>
                "Service2CustomerUser: search data is not a hash ref - ignoring search limitation.",
        );
    }
    my @ServiceList = $Kernel::OM->Get('Kernel::System::Service')->ServiceSearch(
        Name  => $SearchData->{ServiceName} || '',
        Limit => $SearchData->{Limit}       || '0',
        UserID => 1,

        # no further restriction yet...
        #TypeIDs        => 2,
        #CriticalityIDs => 1,
    );

    # export data...
    my @ExportData;

    # get preferences configuration...
    my %Preferences = ();
    if ( $Kernel::OM->Get('Kernel::Config')->Get('ServicePreferences') ) {
        my %PrefConfig = %{ $Kernel::OM->Get('Kernel::Config')->Get('ServicePreferences') };
        for my $CurrKey ( keys(%PrefConfig) ) {
            my %CurrPrefs = ();
            $CurrPrefs{Label}               = $PrefConfig{$CurrKey}->{Label};
            $CurrPrefs{SelectionSource}     = $PrefConfig{$CurrKey}->{SelectionSource};
            $CurrPrefs{GeneralCatalogClass} = $PrefConfig{$CurrKey}->{GeneralCatalogClass};
            $Preferences{ $PrefConfig{$CurrKey}->{PrefKey} } = \%CurrPrefs;
        }
    }

    for my $ServiceID (@ServiceList) {
        my %ServiceData = $Kernel::OM->Get('Kernel::System::Service')->ServiceGet(
            ServiceID => $ServiceID,
            UserID    => 1,            # no permission restriction for this export
        );

        #export valid string instead of ID...
        $ServiceData{Valid} = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
            ValidID => $ServiceData{ValidID},
        );

        if ( $ServiceData{TypeID} ) {
            $ServiceData{Type} = $Self->{ServiceTypeList}->{ $ServiceData{TypeID} };
        }

        PREFERENCECHECK:
        for my $CurrKey ( keys(%ServiceData) ) {

            # check if this is a preference...
            next PREFERENCECHECK if ( !$Preferences{$CurrKey} );

            # check if this is an ID-attribute...
            next PREFERENCECHECK if ( $CurrKey !~ /^(.+)ID$/ );
            my $NamePart = $1;

            # skip if an attribute with a similar name but no "ID" suffix exists...
            next PREFERENCECHECK if ( $ServiceData{$NamePart} );

            # check for source of preference...
            my %SelectionList = ();
            if (
                $Preferences{$CurrKey}->{SelectionSource}
                && $Preferences{$CurrKey}->{SelectionSource} eq 'QueueList'
                )
            {
                %SelectionList = $Kernel::OM->Get('Kernel::System::Queue')->QueueList();
            }
            elsif (
                $Preferences{$CurrKey}->{SelectionSource}
                && $Preferences{$CurrKey}->{SelectionSource} eq 'UserList'
                )
            {
                %SelectionList = Kernel::OM->Get('Kernel::System::UserObject')->UserList(

                    #Type  => 'Long',
                    Valid => 1,
                );
            }
            elsif (
                $Preferences{$CurrKey}->{SelectionSource}
                && $Preferences{$CurrKey}->{SelectionSource} eq 'TypeList'
                )
            {
                %SelectionList = $Kernel::OM->Get('Kernel::System::Type')->TypeList();
            }
            elsif (
                $Preferences{$CurrKey}->{SelectionSource}
                &&$Preferences{$CurrKey}->{SelectionSource} eq 'GeneralCatalog'
                &&$Preferences{$CurrKey}->{GeneralCatalogClass}
            ) {
                my $ItemListRef = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
                    Class => $Preferences{$CurrKey}->{GeneralCatalogClass},
                );
                if ( $ItemListRef && ref($ItemListRef) eq 'HASH' ) {
                    %SelectionList = %{$ItemListRef};
                }
            }

            # create non-ID value for export...
            $ServiceData{$NamePart} = $SelectionList{ $ServiceData{$CurrKey} }
                || $ServiceData{$CurrKey};

        }

        my @CurrRow = qw{};
        for my $MappingObject (@MappingObjectList) {
            my $Key = $MappingObject->{Key};
            if ( $MappingObject->{Key} && $ServiceData{ $MappingObject->{Key} } ) {
                push( @CurrRow, $ServiceData{ $MappingObject->{Key} } );
            }
            else {
                push( @CurrRow, '-' );
            }
        }
        push @ExportData, \@CurrRow;
    }
    return \@ExportData;
}

=item ImportDataSave()

import one row of the import data

    my $ConfigItemID = $ObjectBackend->ImportDataSave(
        TemplateID    => 123,
        ImportDataRow => $ArrayRef,
        UserID        => 1,
    );

=cut

sub ImportDataSave {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID ImportDataRow UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return ( undef, 'Failed' );
        }
    }

    # check import data row
    if ( ref $Param{ImportDataRow} ne 'ARRAY' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'ImportDataRow must be an array reference',
        );
        return ( undef, 'Failed' );
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('Kernel::System::ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check object data
    if ( !$ObjectData || ref $ObjectData ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No object data found for the template id $Param{TemplateID}",
        );
        return ( undef, 'Failed' );
    }

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('Kernel::System::ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check the mapping list
    if ( !$MappingList || ref $MappingList ne 'ARRAY' || !@{$MappingList} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No valid mapping list found for the template id $Param{TemplateID}",
        );
        return ( undef, 'Failed' );
    }

    # create the mapping object list
    my @MappingObjectList;
    my %Identifier;
    my $Counter              = 0;
    my %NewServiceData       = qw{};
    my $ServiceIdentifierKey = "";

    #--------------------------------------------------------------------------
    #BUILD MAPPING TABLE...
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData =
            $Kernel::OM->Get('Kernel::System::ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
            );

        # check mapping object data
        if ( !$MappingObjectData || ref $MappingObjectData ne 'HASH' ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No valid mapping list found for template id $Param{TemplateID}",
            );
            return ( undef, 'Failed' );
        }
        push( @MappingObjectList, $MappingObjectData );
        if (
            $MappingObjectData->{Identifier}
            && $Identifier{ $MappingObjectData->{Key} }
            )
        {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Can't import this entity. "
                    . "'$MappingObjectData->{Key}' has been used multiple "
                    . "times as identifier (line $Param{Counter}).!",
            );
            return ( undef, 'Failed' );
        }
        elsif ( $MappingObjectData->{Identifier} ) {
            $Identifier{ $MappingObjectData->{Key} } =
                $Param{ImportDataRow}->[$Counter];
            $ServiceIdentifierKey = $MappingObjectData->{Key};
        }
        $NewServiceData{ $MappingObjectData->{Key} } =
            $Param{ImportDataRow}->[$Counter];

        #EO special treatment
        $Counter++;
    }

    #--------------------------------------------------------------------------
    # DO THE IMPORT...
    #(0) Preprocess data...
    if ( !$NewServiceData{FullName} ) {
        $NewServiceData{FullName} = $NewServiceData{Name};
    }

    # lookup Valid-ID...
    if ( !$NewServiceData{ValidID} && $NewServiceData{Valid} ) {
        $NewServiceData{ValidID} = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
            Valid => $NewServiceData{Valid}
        );
    }

    # default validity...
    if ( !$NewServiceData{ValidID} ) {
        $NewServiceData{ValidID} = $ObjectData->{DefaultValid} || 1;
    }

    # lookup criticality-ID...
    if (
        $Self->{ReverseCriticalityList}
        && $NewServiceData{Criticality}
        && $Self->{ReverseCriticalityList}->{ $NewServiceData{Criticality} }
        )
    {
        $NewServiceData{CriticalityID} =
            $Self->{ReverseCriticalityList}->{ $NewServiceData{Criticality} };
    }
    if ( !$NewServiceData{CriticalityID} ) {
        $NewServiceData{CriticalityID} = $ObjectData->{DefaultCriticalityID};
    }

    # lookup type-ID...
    if (
        $Self->{ReverseServiceTypeList}
        && $NewServiceData{Type}
        && $Self->{ReverseServiceTypeList}->{ $NewServiceData{Type} }
        )
    {
        $NewServiceData{TypeID} = $Self->{ReverseServiceTypeList}->{ $NewServiceData{Type} };
    }
    if ( !$NewServiceData{TypeID} ) {
        $NewServiceData{TypeID} = $ObjectData->{DefaultServiceTypeID};
    }
    if ( $NewServiceData{Name} && $NewServiceData{Name} =~ /::/ ) {
        my @NamePartsArr = split( "::", $NewServiceData{Name} );
        $NewServiceData{Name}     = pop(@NamePartsArr);
        $NewServiceData{ParentID} = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
            Name => join( "::", @NamePartsArr ),
        );
    }

    #---------------------------------------------------------------------------
    # prepare preferences...

    # get preferences configuration...
    my %Preferences = ();
    if ( $Kernel::OM->Get('Kernel::Config')->Get('ServicePreferences') ) {
        my %PrefConfig = %{ $Kernel::OM->Get('Kernel::Config')->Get('ServicePreferences') };
        for my $CurrKey ( keys(%PrefConfig) ) {
            my %CurrPrefs = ();
            $CurrPrefs{Label}               = $PrefConfig{$CurrKey}->{Label};
            $CurrPrefs{SelectionSource}     = $PrefConfig{$CurrKey}->{SelectionSource};
            $CurrPrefs{GeneralCatalogClass} = $PrefConfig{$CurrKey}->{GeneralCatalogClass};
            $Preferences{ $PrefConfig{$CurrKey}->{PrefKey} } = \%CurrPrefs;
        }
    }

    PREFERENCECHECK:
    for my $CurrKey ( keys(%NewServiceData) ) {
        my $CurrUsedKey = "";
        my $NamePart    = $CurrKey;
        if ( $CurrKey =~ /^(.+)ID$/ ) {
            $NamePart    = $1;
            $CurrUsedKey = $CurrKey;
        }
        else {
            $CurrUsedKey = $CurrKey . "ID";
        }

        # skip if no preference with same name but suffix "ID" exists...
        next PREFERENCECHECK if ( !$Preferences{$CurrUsedKey} );

        # skip if no SelectionSource specified..
        next PREFERENCECHECK if ( !$Preferences{$CurrUsedKey}->{SelectionSource} );

        # check for source of preference...
        my %SelectionList = ();
        if ( $Preferences{$CurrUsedKey}->{SelectionSource} eq 'QueueList' ) {
            %SelectionList = $Kernel::OM->Get('Kernel::System::Queue')->QueueList();
        }
        elsif ( $Preferences{$CurrUsedKey}->{SelectionSource} eq 'TypeList' ) {
            %SelectionList = $Kernel::OM->Get('Kernel::System::Type')->TypeList();
        }
        elsif (
            $Preferences{$CurrUsedKey}->{SelectionSource} eq 'GeneralCatalog'
            &&$Preferences{$CurrUsedKey}->{GeneralCatalogClass}
        ) {
            my $ItemListRef = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
                Class => $Preferences{$CurrUsedKey}->{GeneralCatalogClass},
            );
            if ( $ItemListRef && ref($ItemListRef) eq 'HASH' ) {
                %SelectionList = %{$ItemListRef};
            }
        }
        my %ReverseSelectionList = reverse(%SelectionList);

        # consider '-' values as empty
        $NewServiceData{$CurrUsedKey} = '' if ( $NewServiceData{$CurrUsedKey} eq '-' );
        $NewServiceData{$NamePart}    = '' if ( $NewServiceData{$NamePart}    eq '-' );

        # if only xxxID is given, set xxx...
        if (
            $NewServiceData{$CurrUsedKey}
            && ( !$NewServiceData{$NamePart} || $NamePart eq $CurrUsedKey )
            )
        {
            $NewServiceData{$NamePart} = $SelectionList{ $NewServiceData{$CurrUsedKey} };
        }

        # if xxxID AND xxx are given require uniqeness...
        elsif ( $NewServiceData{$CurrUsedKey} && $NewServiceData{$NamePart} ) {
            my $CompareValue = $SelectionList{ $NewServiceData{$CurrUsedKey} };
            if ( $CompareValue ne $NewServiceData{$NamePart} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Can't import this entity. "
                        . "Ambigous definition of attribute values "
                        . " ($NamePart <$NewServiceData{$NamePart}> does not"
                        . "match $CurrUsedKey <$NewServiceData{$CurrUsedKey}>)!",
                );
                return ( undef, 'Failed' );
            }
        }

        # if only xxx is given and ID can be found - get the ID...
        elsif (
            !$NewServiceData{$CurrUsedKey}
            && $NewServiceData{$NamePart}
            && $ReverseSelectionList{ $NewServiceData{$NamePart} }
            )
        {
            $NewServiceData{$CurrUsedKey} = $ReverseSelectionList{ $NewServiceData{$NamePart} };
        }

        # if only xxx is given and no ID can be found - reject import...
        elsif (
            !$NewServiceData{$CurrUsedKey}
            && $NewServiceData{$NamePart}
            && !$ReverseSelectionList{ $NewServiceData{$NamePart} }
            )
        {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Can't import this entity. "
                    . "Bad definition of attribute value "
                    . " ($NamePart <$NewServiceData{$NamePart}> does not"
                    . "match any existing value in selection)!",
            );
            return ( undef, 'Failed' );
        }

    }

    #---------------------------------------------------------------------------
    #(1) search service...
    my %ServiceData = ();
    my $NewService  = 1;
    my $ServiceID   = $NewServiceData{$ServiceIdentifierKey} || 0;
    if (
        !$ServiceIdentifierKey
        || $ServiceIdentifierKey eq 'Name'
        || !$NewServiceData{$ServiceIdentifierKey}
        )
    {
        if ( $NewServiceData{FullName} ) {
            $ServiceID = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
                Name => $NewServiceData{FullName},
            );
        }
    }
    if ($ServiceID) {
        %ServiceData = $Kernel::OM->Get('Kernel::System::Service')->ServiceGet(
            ServiceID => $ServiceID,
            UserID    => 1,
        );
    }
    if ( scalar( keys(%ServiceData) ) ) {
        $NewService = 0;
    }
    for my $Key ( keys(%NewServiceData) ) {
        next if ( !$NewServiceData{$Key} );
        $ServiceData{$Key} = $NewServiceData{$Key};
    }

    #(2) if service DOES NOT exist => create new...
    my $Result     = 0;
    my $ReturnCode = "";    # Created | Changed | Failed

    if ( $NewService && $ServiceData{Name} && $ServiceData{ValidID} ) {
        if ( $ServiceData{FullName} ) {
            my @NamePartsArr = split( "::", $ServiceData{FullName} );

            pop(@NamePartsArr);
            my $ParentServiceID = 0;
            my $ServiceFullname = '';
            for my $ServicePartName (@NamePartsArr) {
                $ServiceFullname .= '::' if ($ServiceFullname);
                $ServiceFullname .= $ServicePartName;

                my $DummyServiceID = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
                    Name => $ServiceFullname,
                );
                if ( !$DummyServiceID ) {
                    my %ParentServiceData;
                    $ParentServiceData{'Name'} = $ServicePartName;
                    $ParentServiceData{'ParentID'} = $ParentServiceID if $ParentServiceID;

                    for my $ServiceKey (qw(Criticality TypeID ValidID)) {
                        $ParentServiceData{$ServiceKey} = $ServiceData{$ServiceKey}
                            if $ServiceData{$ServiceKey};
                    }

                    $DummyServiceID = $Kernel::OM->Get('Kernel::System::Service')->ServiceAdd(
                        %ParentServiceData,
                        UserID => $Param{UserID},
                    );
                }
                my %NewDummyServiceData = $Kernel::OM->Get('Kernel::System::Service')->ServiceGet(
                    ServiceID => $DummyServiceID,
                    UserID    => 1,
                );
                if (%NewDummyServiceData) {
                    if (
                        (
                               $NewDummyServiceData{ParentID}
                            && $ParentServiceID != $NewDummyServiceData{ParentID}
                        )
                        || ( !$NewDummyServiceData{ParentID} && $ParentServiceID )
                        )
                    {
                        $NewDummyServiceData{ParentID} = $ParentServiceID;
                        $Result = $Kernel::OM->Get('Kernel::System::Service')->ServiceUpdate(
                            %NewDummyServiceData,
                            UserID => $Param{UserID},
                        );
                    }
                    $ParentServiceID = $NewDummyServiceData{ServiceID};
                }
            }
            $ServiceData{ParentID} = $ParentServiceID;
        }
        $Result = $Kernel::OM->Get('Kernel::System::Service')->ServiceAdd(
            %ServiceData,
            UserID => $Param{UserID},
        );
        if ( !$Result ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'ImportDataSave: adding service <'
                    . $ServiceData{Name}
                    . '> failed (line $Param{Counter}).',
            );
        }
        else {
            $ReturnCode = "Created";
            $ServiceID  = $Result;
        }
    }

    #(3) if service DOES exist => update...
    if ( !$NewService && $ServiceData{Name} && $ServiceData{ValidID} ) {
        $Result = $Kernel::OM->Get('Kernel::System::Service')->ServiceUpdate(
            %ServiceData,
            UserID => $Param{UserID},
        );
        if ( !$Result ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'ImportDataSave: updating service <'
                    . $ServiceData{Name}
                    . '> (ID '
                    . $ServiceData{ServiceID}
                    . ') failed (line $Param{Counter}).',
            );
        }
        else {
            $ReturnCode = "Changed";
        }
    }

    #(4) set preferences...
    if ($ServiceID) {
        for my $CurrKey ( keys(%Preferences) ) {
            next if ( !$NewServiceData{$CurrKey} );
            next if ( $NewServiceData{$CurrKey} eq '-' );
            $Kernel::OM->Get('Kernel::System::Service')->ServicePreferencesSet(
                ServiceID => $ServiceID,
                Key       => $CurrKey,
                Value     => $NewServiceData{$CurrKey},
                UserID    => $Param{UserID},
            );
        }
    }

    #
    #--------------------------------------------------------------------------
    return ( $Result, $ReturnCode );
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
