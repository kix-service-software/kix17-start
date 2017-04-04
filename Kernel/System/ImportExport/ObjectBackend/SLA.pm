# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::SLA;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Service',
    'Kernel::System::SLA',
    'Kernel::System::ImportExport',
    'Kernel::System::Valid',
    'Kernel::System::Queue',
    'Kernel::System::Type',
    'Kernel::System::Main',
    'Kernel::System::Log',
    'Kernel::Config',
);

=head1 NAME

Kernel::System::ImportExport::ObjectBackend::CustomerUser - import/export backend for CustomerUser

=head1 SYNOPSIS

All functions to import and export CustomerUser entries

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::DB;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::ImportExport::ObjectBackend::CustomerUser;

    my $ConfigObject = Kernel::Config->new();
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $BackendObject = Kernel::System::ImportExport::ObjectBackend::CustomerUser->new(
        ConfigObject       => $ConfigObject,
        LogObject          => $LogObject,
        DBObject           => $DBObject,
        MainObject         => $MainObject,
        ImportExportObject => $ImportExportObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    my $CalendarIndex    = 1;
    my %CalendarNameList = qw{};
    while (
        $Kernel::OM->Get('Kernel::Config')->Get( "TimeZone::Calendar" . $CalendarIndex . "Name" ) )
    {
        $CalendarNameList{$CalendarIndex} =
            $Kernel::OM->Get('Kernel::Config')
            ->Get( "TimeZone::Calendar" . $CalendarIndex . "Name" );
        $CalendarIndex++;
    }
    my %TmpHash = reverse(%CalendarNameList);
    $Self->{CalendarNameList}        = \%CalendarNameList;
    $Self->{ReverseCalendarNameList} = \%TmpHash;

    if ( $Kernel::OM->Get('Kernel::System::Main')->Require('Kernel::System::GeneralCatalog') ) {
        $Self->{GeneralCatalogObject} = Kernel::System::GeneralCatalog->new( %{$Self} );
        if ( $Self->{GeneralCatalogObject} ) {

            # get SLA type list
            $Self->{SLATypeList} = $Self->{GeneralCatalogObject}->ItemList(
                Class => 'ITSM::SLA::Type',
            );

            if ( $Self->{SLATypeList} && ( ref( $Self->{SLATypeList} ) eq 'HASH' ) )
            {
                my %TmpHash = reverse( %{ $Self->{SLATypeList} } );
                $Self->{ReverseSLATypeList} = \%TmpHash;
            }
        }
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
    my %Validlist = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();

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
        {
            Key   => 'NumberOfAssignableServices',
            Name  => 'Max. number of assigned services columns',
            Input => {
                Type         => 'Text',
                Required     => 1,
                Size         => 3,
                MaxLength    => 3,
                ValueDefault => '50',
            },
        },

    ];

    #use the availability of SLATypeList to display ITSM-relevant config...
    if ( $Self->{SLATypeList} ) {
        my $SLATypeDefault = {
            Key   => 'DefaultSLATypeID',
            Name  => 'Default SLA Type',
            Input => {
                Type         => 'Selection',
                Data         => $Self->{SLATypeList},
                Required     => 1,
                Translation  => 1,
                PossibleNone => 0,
            },
        };
        push( @{$Attributes}, $SLATypeDefault );

        my $MinTimeBetweenIncidentsDefault = {
            Key   => 'DefaultMinTimeBetweenIncidents',
            Name  => 'Default Minimum Time Between Incidents',
            Input => {
                Type      => 'Text',
                Required  => 0,
                Size      => 10,
                MaxLength => 10,
            },
        };
        push( @{$Attributes}, $MinTimeBetweenIncidentsDefault );

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
            Key   => 'SLAID',
            Value => 'SLA ID',
        },
        {
            Key   => 'Name',
            Value => 'SLA Name',
        },
        {
            Key   => 'Calendar',
            Value => 'Calendar Name',
        },
        {
            Key   => 'Valid',
            Value => 'Validity',
        },
        {
            Key   => 'Comment',
            Value => 'Comment',
        },
        {
            Key   => 'FirstResponseTime',
            Value => 'FirstResponseTime (business minutes)',
        },
        {
            Key   => 'FirstResponseNotify',
            Value => 'FirstResponseNotify (percent)',
        },
        {
            Key   => 'UpdateTime',
            Value => 'UpdateTime (business minutes)',
        },
        {
            Key   => 'UpdateNotify',
            Value => 'UpdateNotify (percent)',
        },
        {
            Key   => 'SolutionTime',
            Value => 'SolutionTime (business minutes)',
        },
        {
            Key   => 'SolutionNotify',
            Value => 'SolutionNotify (percent)',
        }
    ];

    #---------------------------------------------------------------------------
    # get preferences...
    my %Preferences = ();
    if ( $Kernel::OM->Get('Kernel::Config')->Get('SLAPreferences') ) {
        %Preferences = %{ $Kernel::OM->Get('Kernel::Config')->Get('SLAPreferences') };
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

    # using SLATypeList as indicator for ITSM-installation...
    if ( $Self->{SLATypeList} ) {
        my $ElementListITSM = [
            {
                Key   => 'Type',
                Value => 'SLA Type (ITSM only)',
            },
            {
                Key   => 'MinTimeBetweenIncidents',
                Value => 'Min. Time Between Incidents (ITSM only)',
            },
        ];
        my @TmpArray = ( @{$ElementList}, @{$ElementListITSM} );
        $ElementList = \@TmpArray;
    }

    # columns for assigned services...
    my $NumberOfAssignableServices = $ObjectData->{NumberOfAssignableServices} || 0;
    my $CurrIndex = 0;
    while ( $CurrIndex < $NumberOfAssignableServices ) {

        push(
            @{$ElementList},
            {
                Key   => 'AssignedService' . sprintf( "%03d", $CurrIndex ),
                Value => 'AssignedService' . sprintf( "%03d", $CurrIndex ),
            }
        );

        $CurrIndex++;
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
            Key   => 'Name',
            Name  => 'SLA Name',
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
                "SLA: search data is not a hash ref - ignoring search limitation.",
        );
    }

    if ( $SearchData && $SearchData->{Name} && $SearchData->{Name} =~ /\*/ ) {
        $SearchData->{Name} =~ s/\*/.*/g;
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

    # export data...
    my @ExportData;

    # get preferences configuration...
    my %Preferences = ();
    if ( $Kernel::OM->Get('Kernel::Config')->Get('SLAPreferences') ) {
        my %PrefConfig = %{ $Kernel::OM->Get('Kernel::Config')->Get('SLAPreferences') };
        for my $CurrKey ( keys(%PrefConfig) ) {
            my %CurrPrefs = ();
            $CurrPrefs{Label}               = $PrefConfig{$CurrKey}->{Label};
            $CurrPrefs{SelectionSource}     = $PrefConfig{$CurrKey}->{SelectionSource};
            $CurrPrefs{GeneralCatalogClass} = $PrefConfig{$CurrKey}->{GeneralCatalogClass};
            $Preferences{ $PrefConfig{$CurrKey}->{PrefKey} } = \%CurrPrefs;
        }
    }

    # search the SLAs...
    my %SLAList = $Kernel::OM->Get('Kernel::System::SLA')->SLAList(
        Valid  => 0,
        UserID => 1,
    );

    for my $CurrSLAID ( keys(%SLAList) ) {

        #check for name (SLA) export filter...
        if ( $SearchData && $SearchData->{Name} ) {
            if ( $SearchData->{Name} =~ /\*/ ) {
                next if ( $SLAList{$CurrSLAID} !~ /$SearchData->{Name}/ );
            }
            else {
                next if ( $SLAList{$CurrSLAID} ne $SearchData->{Name} );
            }
        }

        my %SLAData = $Kernel::OM->Get('Kernel::System::SLA')->SLAGet(
            SLAID  => $CurrSLAID,
            UserID => 1,            # no permission restriction for this export
        );

        #export valid string instead of ID...
        $SLAData{Valid} = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
            ValidID => $SLAData{ValidID},
        );

        PREFERENCECHECK:
        for my $CurrKey ( keys(%SLAData) ) {

            # check if this is a preference...
            next PREFERENCECHECK if ( !$Preferences{$CurrKey} );

            # check if this is an ID-attribute...
            next PREFERENCECHECK if ( $CurrKey !~ /^(.+)ID$/ );
            my $NamePart = $1;

            # skip if an attribute with a similar name but no "ID" suffix exists...
            next PREFERENCECHECK if ( $SLAData{$NamePart} );

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
                && $Preferences{$CurrKey}->{SelectionSource} eq 'TypeList'
                )
            {
                %SelectionList = $Kernel::OM->Get('Kernel::System::Type')->TypeList();
            }
            elsif (
                ( $Preferences{$CurrKey}->{SelectionSource} )
                &&
                ( $Preferences{$CurrKey}->{SelectionSource} eq 'GeneralCatalog' )
                &&
                ( $Preferences{$CurrKey}->{GeneralCatalogClass} ) &&
                $Self->{GeneralCatalogObject}
                )
            {
                my $ItemListRef = $Self->{GeneralCatalogObject}->ItemList(
                    Class => $Preferences{$CurrKey}->{GeneralCatalogClass},
                );
                if ( $ItemListRef && ref($ItemListRef) eq 'HASH' ) {
                    %SelectionList = %{$ItemListRef};
                }
            }

            # create non-ID value for export...
            $SLAData{$NamePart} = $SelectionList{ $SLAData{$CurrKey} }
                || $SLAData{$CurrKey};

        }

        # prepared AssignedServices...
        if ( $SLAData{ServiceIDs} && ref( $SLAData{ServiceIDs} ) eq 'ARRAY' ) {
            my @ServiceIDList = sort @{ $SLAData{ServiceIDs} };
            my $CurrIndex     = 0;
            for my $CurrServiceID (@ServiceIDList) {
                my $CurrKeyName = 'AssignedService' . sprintf( "%03d", $CurrIndex );
                my $CurrService = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
                    ServiceID => $CurrServiceID,
                );
                $SLAData{$CurrKeyName} = $CurrService;
                $CurrIndex++;
            }

        }

        # prepare calendar name
        if ( $SLAData{Calendar} && $Self->{CalendarNameList}->{ $SLAData{Calendar} } ) {
            $SLAData{Calendar} = $Self->{CalendarNameList}->{ $SLAData{Calendar} };
        }

        # create export row...
        my @CurrRow = qw{};
        for my $MappingObject (@MappingObjectList) {
            if ( $MappingObject->{Key} && $SLAData{ $MappingObject->{Key} } ) {
                push( @CurrRow, $SLAData{ $MappingObject->{Key} } );
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
    my $Counter          = 0;
    my %NewSLAData       = qw{};
    my $SLAIdentifierKey = "";

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
                    . "times as identifier.!",
            );
        }
        elsif ( $MappingObjectData->{Identifier} ) {
            $Identifier{ $MappingObjectData->{Key} } =
                $Param{ImportDataRow}->[$Counter];
            $SLAIdentifierKey = $MappingObjectData->{Key};
        }

        $NewSLAData{ $MappingObjectData->{Key} } =
            $Param{ImportDataRow}->[$Counter];

        $Counter++;
    }

    #--------------------------------------------------------------------------
    #DO THE IMPORT...
    #(0) Preprocess data...

    # prepare calendar name...
    if ( $NewSLAData{Calendar} && $Self->{ReverseCalendarNameList}->{ $NewSLAData{Calendar} } ) {
        $NewSLAData{Calendar} = $Self->{ReverseCalendarNameList}->{ $NewSLAData{Calendar} };
    }

    # lookup Valid-ID...
    if ( !$NewSLAData{ValidID} && $NewSLAData{Valid} ) {
        $NewSLAData{ValidID} = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
            Valid => $NewSLAData{Valid}
        );
    }
    if ( !$NewSLAData{ValidID} ) {
        $NewSLAData{ValidID} = $ObjectData->{DefaultValid} || 1;
    }

    # lookup type-ID...
    if (
        $Self->{ReverseSLATypeList}
        && $NewSLAData{Type}
        && $Self->{ReverseSLATypeList}->{ $NewSLAData{Type} }
        )
    {
        $NewSLAData{TypeID} = $Self->{ReverseSLATypeList}->{ $NewSLAData{Type} };
    }
    if ( !$NewSLAData{TypeID} ) {
        $NewSLAData{TypeID} = $ObjectData->{DefaultSLATypeID};
    }

    # lookup assigned ServiceIDs
    my $NumberOfAssignableServices = $ObjectData->{NumberOfAssignableServices} || 0;
    my $CurrIndex                  = 0;
    my @NewServiceIDs              = qw{};
    while ( $CurrIndex < $NumberOfAssignableServices ) {
        my $CurrKeyName = 'AssignedService' . sprintf( "%03d", $CurrIndex );

        if ( $NewSLAData{$CurrKeyName} && $NewSLAData{$CurrKeyName} ne '-' ) {
            my $CurrServiceID = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
                Name => $NewSLAData{$CurrKeyName},
            );
            if ($CurrServiceID) {
                push( @NewServiceIDs, $CurrServiceID );
            }
        }

        $CurrIndex++;
    }

    #---------------------------------------------------------------------------
    # prepare preferences...

    # get preferences configuration...
    my %Preferences = ();
    if ( $Kernel::OM->Get('Kernel::Config')->Get('SLAPreferences') ) {
        my %PrefConfig = %{ $Kernel::OM->Get('Kernel::Config')->Get('SLAPreferences') };
        for my $CurrKey ( keys(%PrefConfig) ) {
            my %CurrPrefs = ();
            $CurrPrefs{Label}               = $PrefConfig{$CurrKey}->{Label};
            $CurrPrefs{SelectionSource}     = $PrefConfig{$CurrKey}->{SelectionSource};
            $CurrPrefs{GeneralCatalogClass} = $PrefConfig{$CurrKey}->{GeneralCatalogClass};
            $Preferences{ $PrefConfig{$CurrKey}->{PrefKey} } = \%CurrPrefs;
        }
    }

    PREFERENCECHECK:
    for my $CurrKey ( keys(%NewSLAData) ) {
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
            ( $Preferences{$CurrUsedKey}->{SelectionSource} eq 'GeneralCatalog' )
            &&
            ( $Preferences{$CurrUsedKey}->{GeneralCatalogClass} ) &&
            $Self->{GeneralCatalogObject}
            )
        {
            my $ItemListRef = $Self->{GeneralCatalogObject}->ItemList(
                Class => $Preferences{$CurrUsedKey}->{GeneralCatalogClass},
            );
            if ( $ItemListRef && ref($ItemListRef) eq 'HASH' ) {
                %SelectionList = %{$ItemListRef};
            }
        }
        my %ReverseSelectionList = reverse(%SelectionList);

        # if only xxxID is given, set xxx...
        if (
            $NewSLAData{$CurrUsedKey}
            && ( !$NewSLAData{$NamePart} || $NamePart eq $CurrUsedKey )
            )
        {
            $NewSLAData{$NamePart} = $SelectionList{ $NewSLAData{$CurrUsedKey} };
        }

        # if xxxID AND xxx are given require uniqeness...
        elsif ( $NewSLAData{$CurrUsedKey} && $NewSLAData{$NamePart} ) {
            my $CompareValue = $SelectionList{ $NewSLAData{$CurrUsedKey} };
            if ( $CompareValue ne $NewSLAData{$NamePart} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Can't import this entity. "
                        . "Ambigous definition of attribute values "
                        . " ($NamePart <$NewSLAData{$NamePart}> does not"
                        . "match $CurrUsedKey <$NewSLAData{$CurrUsedKey}>)!",
                );
                return ( undef, 'Failed' );
            }
        }

        # if only xxx is given and ID can be found - get the ID...
        elsif (
            !$NewSLAData{$CurrUsedKey}
            && $NewSLAData{$NamePart}
            && $ReverseSelectionList{ $NewSLAData{$NamePart} }
            )
        {
            $NewSLAData{$CurrUsedKey} = $ReverseSelectionList{ $NewSLAData{$NamePart} };
        }

        # if only xxx is given and no ID can be found - reject import...
        elsif (
            !$NewSLAData{$CurrUsedKey}
            && $NewSLAData{$NamePart}
            && !$ReverseSelectionList{ $NewSLAData{$NamePart} }
            )
        {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Can't import this entity. "
                    . "Bad definition of attribute value "
                    . " ($NamePart <$NewSLAData{$NamePart}> does not"
                    . "match any existing value in selection)!",
            );
            return ( undef, 'Failed' );
        }

    }

    #---------------------------------------------------------------------------
    #(1) search SLA...
    my %SLAData = ();
    my $NewSLA  = 1;
    my $SLAID   = $NewSLAData{$SLAIdentifierKey} || 0;

    if (
        ( !$SLAIdentifierKey || $SLAIdentifierKey eq 'Name' || !$NewSLAData{$SLAIdentifierKey} )
        && $NewSLAData{Name}
        )
    {
        $SLAID = $Kernel::OM->Get('Kernel::System::SLA')->SLALookup(
            Name => $NewSLAData{Name},
        );
    }

    if ( $SLAID && $SLAID =~ /\d+/ ) {
        %SLAData = $Kernel::OM->Get('Kernel::System::SLA')->SLAGet(
            SLAID  => $SLAID,
            UserID => 1,
        );
    }
    elsif ($SLAID) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => 'ImportDataSave: SLAID <' . $SLAID . '> is not a number '
                . '(maybe label or headline).',
        );
        return ( undef, 'Failed' );
    }

    if ( scalar( keys(%SLAData) ) ) {
        $NewSLA = 0;
    }

    for my $Key ( keys(%NewSLAData) ) {
        next if ( !$NewSLAData{$Key} );
        $SLAData{$Key} = $NewSLAData{$Key};
    }

    for my $CurrKey (
        qw( FirstResponseTime FirstResponseNotify UpdateTime
        UpdateNotify SolutionTime SolutionNotify MinTimeBetweenIncidents)
        )
    {
        if ( $SLAData{$CurrKey} && $SLAData{$CurrKey} eq '-' ) {
            delete( $SLAData{$CurrKey} );
        }
    }

    $SLAData{ServiceIDs} = \@NewServiceIDs;

    #(2) if SLA DOES NOT exists => create new...
    my $Result     = 0;
    my $ReturnCode = "";    # Created | Changed | Failed

    if ($NewSLA) {
        $Result = $Kernel::OM->Get('Kernel::System::SLA')->SLAAdd(
            %SLAData,
            UserID => $Param{UserID},
        );

        if ( !$Result ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'ImportDataSave: adding SLA <'
                    . $SLAData{Name}
                    . '> failed.',
            );
        }
        else {
            $ReturnCode = "Created";
        }
    }

    #(3) if SLA DOES exists => update...
    if ( !$NewSLA ) {
        $Result = $Kernel::OM->Get('Kernel::System::SLA')->SLAUpdate(
            %SLAData,
            UserID => $Param{UserID},
        );

        if ( !$Result ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'ImportDataSave: updating SLA <'
                    . $SLAData{Name}
                    . '> (ID '
                    . $SLAData{SLAID}
                    . ') failed.',
            );
        }
        else {
            $ReturnCode = "Changed";
        }
    }

    #(4) set preferences...
    if ($SLAID) {
        for my $CurrKey ( keys(%Preferences) ) {
            next if ( !$NewSLAData{$CurrKey} );
            $Kernel::OM->Get('Kernel::System::SLA')->SLAPreferencesSet(
                SLAID  => $SLAID,
                Key    => $CurrKey,
                Value  => $NewSLAData{$CurrKey},
                UserID => $Param{UserID},
            );
        }
    }
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
