# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::User;

use strict;
use warnings;
use Kernel::System::User;
use Kernel::System::Valid;
use Kernel::System::Time;
use Kernel::System::Queue;
use Kernel::System::Group;
use Time::Local;

use vars qw($VERSION);
$VERSION = qw($Revision$) [1];

our @ObjectDependencies = (
    'Kernel::System::ImportExport',
    'Kernel::System::User',
    'Kernel::System::Queue',
    'Kernel::System::Group',
    'Kernel::System::Log',
    'Kernel::Config'
);

=head1 NAME

Kernel::System::ImportExport::ObjectBackend::User - import/export backend for User

=head1 SYNOPSIS

All functions to import and export User entries

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::DB;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::ImportExport::ObjectBackend::User;

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
    my $BackendObject = Kernel::System::ImportExport::ObjectBackend::User->new(
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
            Key   => 'DefaultUserEmail',
            Name  => 'Default Email',
            Input => {
                Type         => 'Text',
                Required     => 0,
                Size         => 50,
                MaxLength    => 250,
                ValueDefault => $Kernel::OM->Get('Kernel::Config')->Get(
                    'UserImport::DefaultEmailAddress',
                    )
            },
        },
        {
            Key   => 'DefaultPassword',
            Name  => 'Password Suffix (pw=login+suffix - only import)',
            Input => {
                Type         => 'Text',
                Required     => 0,
                Size         => 50,
                MaxLength    => 250,
                ValueDefault => $Kernel::OM->Get('Kernel::Config')->Get(
                    'UserImport::DefaultPassword',
                    )
            },
        },
        {
            Key   => 'NumberOfCustomQueues',
            Name  => 'Max. number of Custom Queues',
            Input => {
                Type         => 'Text',
                Required     => 1,
                Size         => 3,
                MaxLength    => 3,
                ValueDefault => '10',
            },
        },
        {
            Key   => 'NumberOfRoles',
            Name  => 'Max. number of roles',
            Input => {
                Type         => 'Text',
                Required     => 1,
                Size         => 3,
                MaxLength    => 3,
                ValueDefault => '10',
            },
        },
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
    my @ElementList = qw{};
    for my $Parameter (
        qw(UserTitle UserLogin UserFirstname UserLastname UserEmail UserPw ValidID
        UserTheme UserLanguage UserComment UserSkin OutOfOffice OutOfOfficeStartYear OutOfOfficeStartMonth
        OutOfOfficeStartDay OutOfOfficeEndYear OutOfOfficeEndMonth OutOfOfficeEndDay UserSendMoveNotification
        UserSendFollowUpNotification UserSendNewTicketNotification UserSendLockTimeoutNotification)
        )
    {
        my $CurrAttribute = {
            Key   => $Parameter,
            Value => $Parameter,
        };

        # if ValidID is available - offer Valid instead..
        if ( $Parameter eq 'ValidID' ) {
            $CurrAttribute = { Key => 'Valid', Value => 'Validity', };
        }

        # if UserPw is available - add note to mapping..
        if ( $Parameter eq 'UserPw' ) {
            $CurrAttribute = {
                Key => 'UserPw',
                Value =>
                    'UserPw (not filled in export, relevant only for import of new entries)',
            };
        }

        # required mapping-elements
        if ( $Parameter eq 'UserLogin' ) {
            $CurrAttribute = {
                Key   => $Parameter,
                Value => "$Parameter (required for import)",
            };
        }
        if ( $Parameter eq 'UserFirstname' || $Parameter eq 'UserLastname' ) {
            $CurrAttribute = {
                Key   => $Parameter,
                Value => "$Parameter (required for import of new entries)",
            };
        }
        push( @ElementList, $CurrAttribute );
    }

=more Preferences:
UserCreateNextMask UserTicketOverviewSmallPageShown UserTicketOverviewPreviewPageShown
UserConfigItemOverviewSmallPageShown UserChangeOverviewSmallPageShown UserRefreshTime UserTicketOverviewMediumPageShown
=cut

    # columns for CustomQueues
    my $NumberOfCustomQueues = $ObjectData->{NumberOfCustomQueues} || 10;
    my $CurrIndex = 0;
    while ( $CurrIndex < $NumberOfCustomQueues ) {

        push(
            @ElementList,
            {
                Key   => 'CustomQueue' . sprintf( "%03d", $CurrIndex ),
                Value => 'CustomQueue' . sprintf( "%03d", $CurrIndex ),
            }
        );

        $CurrIndex++;
    }

    # columns for roles
    my $NumberOfRoles = $ObjectData->{NumberOfRoles} || 10;
    $CurrIndex = 0;
    while ( $CurrIndex < $NumberOfRoles ) {

        push(
            @ElementList,
            {
                Key   => 'Role' . sprintf( "%03d", $CurrIndex ),
                Value => 'Role' . sprintf( "%03d", $CurrIndex ),
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
                Data         => \@ElementList,
                Required     => 1,
                Translation  => 0,
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

    # get object data
    my $ObjectData = $Kernel::OM->Get('Kernel::System::ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    return;
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

    # search the users...
    my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserSearch(
        Search => '*',
        Valid  => 0,
    );
    my @ExportData;

    # export user ...
    for my $CurrUser ( keys(%UserList) ) {
        my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID        => $CurrUser,
            NoOutOfOffice => 1,
        );

        # prepare validity...
        if ( $UserData{ValidID} ) {
            $UserData{Valid} = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
                ValidID => $UserData{ValidID},
            );
        }

        # prepare password...
        if ( $UserData{UserPw} ) {
            $UserData{UserPw} = '-';
        }

        # prepare preferences
        for my $Argument (
            qw(OutOfOffice UserSendMoveNotification UserSendFollowUpNotification UserSendNewTicketNotification UserSendLockTimeoutNotification)
            )
        {
            if   ( $UserData{$Argument} ) { $UserData{$Argument} = 'yes' }
            else                          { $UserData{$Argument} = 'no' }
        }

        # get CustomQueues
        my @QueueIDs = $Kernel::OM->Get('Kernel::System::Queue')->GetAllCustomQueues(
            UserID => $CurrUser,
        );
        if (@QueueIDs) {
            my $CurrIndex = 0;
            my $NumberOfCustomQueues = $ObjectData->{NumberOfCustomQueues} || 10;
            for my $QueueID (@QueueIDs) {
                if ( $CurrIndex < $NumberOfCustomQueues ) {
                    my $Queue = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
                        QueueID => $QueueID,
                    );
                    $UserData{ 'CustomQueue' . sprintf( "%03d", $CurrIndex ) } = $Queue;
                }
                $CurrIndex++;
            }
        }

        # get roles
        my @RoleIDs = $Kernel::OM->Get('Kernel::System::Group')->GroupUserRoleMemberList(
            UserID => $CurrUser,
            Result => 'ID',
        );
        if (@RoleIDs) {
            my $CurrIndex = 0;
            my $NumberOfRoles = $ObjectData->{NumberOfRoles} || 10;
            for my $RoleID (@RoleIDs) {
                if ( $CurrIndex < $NumberOfRoles ) {
                    my $Role = $Kernel::OM->Get('Kernel::System::Group')
                        ->RoleLookup( RoleID => $RoleID );
                    $UserData{ 'Role' . sprintf( "%03d", $CurrIndex ) } = $Role;
                }
                $CurrIndex++;
            }
        }

        my @CurrRow;
        for my $MappingObject (@MappingObjectList) {
            my $Key = $MappingObject->{Key};
            if ( !$Key ) {
                push @CurrRow, '';
            }
            else {
                push( @CurrRow, $UserData{$Key} || '' );
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
    my $Counter     = 0;
    my %NewUserData = qw{};
    my $UserKey     = "";

    #--------------------------------------------------------------------------
    #BUILD MAPPING TABLE...
    my $IsHeadline = 1;
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
        }
        elsif ( $MappingObjectData->{Identifier} ) {
            $Identifier{ $MappingObjectData->{Key} } =
                $Param{ImportDataRow}->[$Counter];
            $UserKey = $MappingObjectData->{Key};
        }
        $NewUserData{ $MappingObjectData->{Key} } =
            $Param{ImportDataRow}->[$Counter];
        $Counter++;
    }

    #--------------------------------------------------------------------------
    #DO THE IMPORT...
    #(0) Preprocess data...
    # lookup Valid-ID...

    if ( !$NewUserData{ValidID} && $NewUserData{Valid} ) {
        $NewUserData{ValidID} = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
            Valid => $NewUserData{Valid}
        );
    }
    if ( !$NewUserData{ValidID} ) {
        $NewUserData{ValidID} = $ObjectData->{DefaultValid} || 1;
    }

    #(1) search user
    my %UserData = ();
    if ( !$UserKey || $UserKey ne 'UserLogin' ) {
        $UserKey = "UserLogin";
    }

    if ( $NewUserData{$UserKey} ) {
        %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            User => $NewUserData{$UserKey}
        );
    }

    # no update of root@localhost
    if ( $UserData{UserID} && $UserData{UserID} == 1 ) {
        next;
    }

    my $NewUser = 1;
    if (%UserData) {
        $NewUser = 0;
    }

    for my $Key ( keys(%NewUserData) ) {
        $UserData{$Key} = $NewUserData{$Key};
    }

    if ( !$UserData{ValidID} ) {
        $UserData{ValidID} = 1;
    }

    #(1) Preprocess data...

    #default UserEmail...
    if ( !$UserData{UserEmail} ) {
        $UserData{UserEmail} = $ObjectData->{DefaultUserEmail}
            || $Kernel::OM->Get('Kernel::Config')->Get(
            'UserImport::DefaultEmailAddress'
            );
    }

    #(2) if user DOES NOT exist => create
    my $Result     = 0;
    my $ReturnCode = "";    # Created | Changed | Failed

    if ($NewUser) {

        # set defaults
        delete $UserData{ID};

        # default UserPw
        if ( !$UserData{UserPw} || $UserData{UserPw} eq '-' ) {
            $UserData{UserPw} = $UserData{UserLogin} . (
                $ObjectData->{DefaultPassword} || $Kernel::OM->Get('Kernel::Config')->Get(
                    'UserImport::DefaultPassword'
                    )
                )
        }
        $Result = $Kernel::OM->Get('Kernel::System::User')->UserAdd(
            %UserData,
            ChangeUserID => $Param{UserID},
        );

        if ( !$Result ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "ImportDataSave: adding User ("
                    . "Login "
                    . $UserData{UserLogin}
                    . ") failed (line $Param{Counter}).",
            );
        }
        else {
            $ReturnCode = "Created";
        }
    }

    #(3) if user DOES exist => update...
    else {
        $UserData{ID} = $NewUserData{$UserKey};

        delete $UserData{UserPw};
        $Result = $Kernel::OM->Get('Kernel::System::User')->UserUpdate(
            %UserData,
            ChangeUserID => $Param{UserID},
        );

        if ( !$Result ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "ImportDataSave: updating User ("
                    . "Login "
                    . $UserData{UserLogin}
                    . ") failed (line $Param{Counter}).",
            );
        }
        else {
            $ReturnCode = "Changed";
        }
    }

    # (4) queues, roles, preferences
    if ($Result) {

        # get UserID
        my $UserID;
        if ($NewUser) {
            $UserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
                UserLogin => $UserData{UserLogin},
            );
        }
        else {
            $UserID = $UserData{UserID};
        }

        # set CustomQueues
        # delete existing entries
        $Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL  => 'DELETE FROM personal_queues WHERE user_id = ?',
            Bind => [ \$UserID ],
        );

        my $CurrIndex = 0;
        my $NumberOfCustomQueues = $ObjectData->{NumberOfCustomQueues} || 10;
        while ( $CurrIndex < $NumberOfCustomQueues ) {
            if ( $UserData{ 'CustomQueue' . sprintf( "%03d", $CurrIndex ) } ) {

                # get QueueID
                my $QueueID = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
                    Queue => $UserData{ 'CustomQueue' . sprintf( "%03d", $CurrIndex ) }
                );

                # create new entry
                if ($QueueID) {
                    my $Success = $Kernel::OM->Get('Kernel::System::DB')->Do(
                        SQL => 'INSERT INTO personal_queues (user_id, queue_id) VALUES ('
                            . $UserID . ','
                            . $QueueID
                            . ')',
                    );
                    $ReturnCode = "Partially changed - see log for details" if ( !$Success );
                }
                else {
                    $ReturnCode = "Partially changed - see log for details";
                }
            }
            $CurrIndex++;
        }

        # set Preferences
        # check OutOfOffice-Date
        if ( $UserData{OutOfOffice} ) {
            my $Check;
            for (qw(Start End)) {
                my $CheckDate;
                if ( $UserData{ 'OutOfOffice' . $_ . 'Year' } =~ m/\d{4}/ ) {
                    $CheckDate = eval {
                        timelocal(
                            0, 0, 0, $UserData{ 'OutOfOffice' . $_ . 'Day' },
                            ( $UserData{ 'OutOfOffice' . $_ . 'Month' } - 1 ),
                            $UserData{ 'OutOfOffice' . $_ . 'Year' }
                        );
                    };
                }
                if ( !$CheckDate ) {
                    $UserData{ 'OutOfOffice' . $_ . 'Year' }  = '';
                    $UserData{ 'OutOfOffice' . $_ . 'Month' } = '';
                    $UserData{ 'OutOfOffice' . $_ . 'Day' }   = '';
                    if ( $UserData{OutOfOffice} ne 'no' ) {
                        $Kernel::OM->Get('Kernel::System::Log')->Log(
                            Priority => 'error',
                            Message =>
                                'Import: Invalid OutOfOffice' . $_ . '-Date for User '
                                . $UserData{UserLogin},
                        );

                    }
                    $Check = 1;
                }
            }
            if ($Check) { $UserData{OutOfOffice} = 'no' }
        }
        else {
            for (
                qw(OutOfOfficeStartYear OutOfOfficeStartMonth OutOfOfficeStartDay
                OutOfOfficeEndYear OutOfOfficeEndMonth OutOfOfficeEndDay)
                )
            {
                $UserData{$_} = "";
            }
        }
        for my $Preference (
            qw(UserTheme UserLanguage UserComment UserSkin OutOfOfficeStartYear OutOfOfficeStartMonth OutOfOfficeStartDay
            OutOfOfficeEndYear OutOfOfficeEndMonth OutOfOfficeEndDay OutOfOffice UserSendMoveNotification
            UserSendFollowUpNotification UserSendNewTicketNotification UserSendLockTimeoutNotification)
            )
        {

            if ( $UserData{$Preference} ) {

                #check OutOfOffice and UserSend...Notifications
                if ( $Preference =~ m/^UserSend.+/ || $Preference =~ m/^OutOfOffice$/ ) {
                    if ( $UserData{$Preference} eq 'no' ) {
                        $UserData{$Preference} = 0;
                    }
                    else { $UserData{$Preference} = 1; }
                }
                $Kernel::OM->Get('Kernel::System::User')->SetPreferences(
                    Key    => $Preference,
                    Value  => $UserData{$Preference},
                    UserID => $UserID,
                );
            }
        }

=more Preferences:
UserCreateNextMask UserTicketOverviewSmallPageShown UserTicketOverviewPreviewPageShown
UserConfigItemOverviewSmallPageShown UserChangeOverviewSmallPageShown UserRefreshTime UserTicketOverviewMediumPageShown
=cut

        # set roles
        # delete existing entries
        $Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL  => 'DELETE FROM role_user WHERE user_id = ?',
            Bind => [ \$UserID ],
        );

        $CurrIndex = 0;
        my $NumberOfRoles = $ObjectData->{NumberOfRoles} || 10;
        while ( $CurrIndex < $NumberOfRoles ) {
            if ( $UserData{ 'Role' . sprintf( "%03d", $CurrIndex ) } ) {

                # get RoleID
                my $RoleID = $Kernel::OM->Get('Kernel::System::Group')->RoleLookup(
                    Role => $UserData{ 'Role' . sprintf( "%03d", $CurrIndex ) },
                );

                #create new entry
                if ($RoleID) {
                    my $Success = $Kernel::OM->Get('Kernel::System::Group')->GroupUserRoleMemberAdd(
                        UID    => $UserID,
                        RID    => $RoleID,
                        Active => 1,
                        UserID => $Param{UserID},
                    );
                    $ReturnCode = "Partially changed - see log for details" if ( !$Success );

                }
                else {
                    $ReturnCode = "Partially changed - see log for details";
                }
            }
            $CurrIndex++;
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
