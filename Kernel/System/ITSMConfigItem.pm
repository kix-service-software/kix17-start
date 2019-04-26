# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem;

use strict;
use warnings;

use Kernel::System::EventHandler;
use Kernel::System::PreEventHandler;
use Kernel::System::ITSMConfigItem::Definition;
use Kernel::System::ITSMConfigItem::History;
use Kernel::System::ITSMConfigItem::Number;
use Kernel::System::ITSMConfigItem::Permission;
use Kernel::System::ITSMConfigItem::Version;
use Kernel::System::ITSMConfigItem::XML;
use Kernel::System::VariableCheck qw(:all);

use Storable;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Cache',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Service',
    'Kernel::System::User',
    'Kernel::System::VirtualFS',
    'Kernel::System::XML',
);

=head1 NAME

Kernel::System::ITSMConfigItem - config item lib

=head1 SYNOPSIS

All config item functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'ITSMConfigurationManagement';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 25;     # 25 days - don't exceed 29 days here, because memcached can't handle TTLs above 30 days

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    use base qw(
        Kernel::System::ITSMConfigItem::Definition
        Kernel::System::ITSMConfigItem::History
        Kernel::System::ITSMConfigItem::Number
        Kernel::System::ITSMConfigItem::Permission
        Kernel::System::ITSMConfigItem::Version
        Kernel::System::ITSMConfigItem::XML
        Kernel::System::EventHandler
        Kernel::System::PreEventHandler
    );

    # load ticket extension modules
    my $CustomModule = $ConfigObject->Get('ITSMConfigItem::CustomModules');
    if ($CustomModule) {

        my %ModuleList;
        if ( ref $CustomModule eq 'HASH' ) {
            %ModuleList = %{$CustomModule};
        }
        else {
            $ModuleList{Init} = $CustomModule;
        }

        MODULEKEY:
        for my $ModuleKey ( sort keys %ModuleList ) {

            my $Module = $ModuleList{$ModuleKey};

            next MODULEKEY if !$Module;
            next MODULEKEY if !$MainObject->RequireBaseClass($Module);
        }
    }

    # init of pre-event handler
    $Self->PreEventHandlerInit(
        Config     => 'ITSMConfigItem::EventModulePre',
        BaseObject => 'ConfigItemObject',
        Objects    => {
            %{$Self},
        },
    );

    # init of event handler
    $Self->EventHandlerInit(
        Config => 'ITSMConfigItem::EventModulePost',
    );

    return $Self;
}

=item ConfigItemCount()

count all records of a config item class

    my $Count = $ConfigItemObject->ConfigItemCount(
        ClassID               => 123,
        IncludePostproductive => 1     # optional, 0 is default
    );

=cut

sub ConfigItemCount {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ClassID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ClassID!',
        );
        return;
    }

    # get state list
    my @Functionality = ( 'preproductive', 'productive' );
    push( @Functionality, 'postproductive' ) if ( $Param{IncludePostproductive} );
    my $StateList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class       => 'ITSM::ConfigItem::DeploymentState',
        Preferences => {
            Functionality => \@Functionality,
        },
    );

    return 0 if !%{$StateList};

    # create state string
    my $DeplStateString = join q{, }, keys %{$StateList};

    # ask database
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => "SELECT COUNT(id) FROM configitem WHERE class_id = ? AND "
            . "cur_depl_state_id IN ( $DeplStateString )",
        Bind  => [ \$Param{ClassID} ],
        Limit => 1,
    );

    # fetch the result
    my $Count = 0;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $Count = $Row[0];
    }

    return $Count;
}

=item ConfigItemResultList()

return a config item list as array hash reference

    my $ConfigItemListRef = $ConfigItemObject->ConfigItemResultList(
        ClassID => 123,
        Start   => 100,
        Limit   => 50,
    );

=cut

sub ConfigItemResultList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ClassID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ClassID!',
        );
        return;
    }

    # get state list
    my $StateList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class       => 'ITSM::ConfigItem::DeploymentState',
        Preferences => {
            Functionality => [ 'preproductive', 'productive' ],
        },
    );

    # create state string
    my $DeplStateString = join q{, }, keys %{$StateList};

    # ask database
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => "SELECT id FROM configitem "
            . "WHERE class_id = ? AND cur_depl_state_id IN ( $DeplStateString ) "
            . "ORDER BY change_time DESC",
        Bind  => [ \$Param{ClassID} ],
        Start => $Param{Start},
        Limit => $Param{Limit},
    );

    # fetch the result
    my @ConfigItemIDList;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        push @ConfigItemIDList, $Row[0];
    }

    # get last versions data
    my @ConfigItemList;
    for my $ConfigItemID (@ConfigItemIDList) {

        # get version data
        my $LastVersion = $Self->VersionGet(
            ConfigItemID => $ConfigItemID,
            XMLDataGet   => 0,
        );

        push @ConfigItemList, $LastVersion;
    }

    return \@ConfigItemList;
}

=item ConfigItemGet()

return a config item as hash reference

    my $ConfigItem = $ConfigItemObject->ConfigItemGet(
        ConfigItemID => 123,
        Cache        => 0,    # (optional) default 1 (0|1)
    );

A hashref with the following keys is returned:

    $ConfigItem{ConfigItemID}
    $ConfigItem{Number}
    $ConfigItem{ClassID}
    $ConfigItem{Class}
    $ConfigItem{LastVersionID}
    $ConfigItem{CurDeplStateID}
    $ConfigItem{CurDeplState}
    $ConfigItem{CurDeplStateType}
    $ConfigItem{CurInciStateID}
    $ConfigItem{CurInciState}
    $ConfigItem{CurInciStateType}
    $ConfigItem{CreateTime}
    $ConfigItem{CreateBy}
    $ConfigItem{ChangeTime}
    $ConfigItem{ChangeBy}

=cut

sub ConfigItemGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ConfigItemID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ConfigItemID!',
        );
        return;
    }

    # enable cache per default
    if ( !defined $Param{Cache} ) {
        $Param{Cache} = 1;
    }

    # check if result is already cached
    my $CacheKey    = 'ConfigItemGet::ConfigItemID::' . $Param{ConfigItemID};
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    my $Cache       = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return Storable::dclone($Cache) if $Cache;

    # ask database
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id, configitem_number, class_id, last_version_id, '
            . 'cur_depl_state_id, cur_inci_state_id, '
            . 'create_time, create_by, change_time, change_by '
            . 'FROM configitem WHERE id = ?',
        Bind  => [ \$Param{ConfigItemID} ],
        Limit => 1,
    );

    # fetch the result
    my %ConfigItem;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $ConfigItem{ConfigItemID}   = $Row[0];
        $ConfigItem{Number}         = $Row[1];
        $ConfigItem{ClassID}        = $Row[2];
        $ConfigItem{LastVersionID}  = $Row[3];
        $ConfigItem{CurDeplStateID} = $Row[4];
        $ConfigItem{CurInciStateID} = $Row[5];
        $ConfigItem{CreateTime}     = $Row[6];
        $ConfigItem{CreateBy}       = $Row[7];
        $ConfigItem{ChangeTime}     = $Row[8];
        $ConfigItem{ChangeBy}       = $Row[9];
    }

    # check config item
    if ( !$ConfigItem{ConfigItemID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such ConfigItemID ($Param{ConfigItemID})!",
        );
        return;
    }

    # get class list
    my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    $ConfigItem{Class} = $ClassList->{ $ConfigItem{ClassID} };

    return \%ConfigItem if !$ConfigItem{CurDeplStateID} || !$ConfigItem{CurInciStateID};

    # get deployment state functionality
    my $DeplState = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemGet(
        ItemID => $ConfigItem{CurDeplStateID},
    );

    $ConfigItem{CurDeplState}     = $DeplState->{Name};
    $ConfigItem{CurDeplStateType} = $DeplState->{Functionality};

    # get incident state functionality
    my $InciState = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemGet(
        ItemID => $ConfigItem{CurInciStateID},
    );

    $ConfigItem{CurInciState}     = $InciState->{Name};
    $ConfigItem{CurInciStateType} = $InciState->{Functionality};

    # cache the result
    $CacheObject->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => Storable::dclone( \%ConfigItem ),
    );

    return \%ConfigItem;
}

=item ConfigItemAdd()

add a new config item

    my $ConfigItemID = $ConfigItemObject->ConfigItemAdd(
        Number  => '111',  # (optional)
        ClassID => 123,
        UserID  => 1,
    );

=cut

sub ConfigItemAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ClassID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get class list
    my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    return if !$ClassList;
    return if ref $ClassList ne 'HASH';

    # check the class id
    if ( !$ClassList->{ $Param{ClassID} } ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No valid class id given!',
        );
        return;
    }

    # trigger ConfigItemCreate
    my $Result = $Self->PreEventHandler(
        Event => 'ConfigItemCreate',
        Data  => {
            ClassID => $Param{ClassID},
            UserID  => $Param{UserID},
            Version => $Param{Version} || '',
        },
        UserID => $Param{UserID},
    );
    if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Pre-ConfigItemAdd refused CI creation.",
        );
        return $Result;
    }
    elsif ( ref($Result) eq 'HASH' ) {
        for my $ResultKey ( keys %{$Result} ) {
            $Param{$ResultKey} = $Result->{$ResultKey};
        }
    }

    # create config item number
    if ( $Param{Number} ) {

        # find existing config item number
        my $Exists = $Self->ConfigItemNumberLookup(
            ConfigItemNumber => $Param{Number},
        );

        if ($Exists) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Config item number already exists!',
            );
            return;
        }
    }
    else {

        # create config item number
        $Param{Number} = $Self->ConfigItemNumberCreate(
            Type    => $Kernel::OM->Get('Kernel::Config')->Get('ITSMConfigItem::NumberGenerator'),
            ClassID => $Param{ClassID},
        );
    }

    # insert new config item
    my $Success = $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'INSERT INTO configitem '
            . '(configitem_number, class_id, create_time, create_by, change_time, change_by) '
            . 'VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [ \$Param{Number}, \$Param{ClassID}, \$Param{UserID}, \$Param{UserID} ],
    );

    return if !$Success;

    # find id of new item
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id FROM configitem WHERE '
            . 'configitem_number = ? AND class_id = ? ORDER BY id DESC',
        Bind  => [ \$Param{Number}, \$Param{ClassID} ],
        Limit => 1,
    );

    # fetch the result
    my $ConfigItemID;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $ConfigItemID = $Row[0];
    }

    # trigger ConfigItemCreate
    $Self->EventHandler(
        Event => 'ConfigItemCreate',
        Data  => {
            ConfigItemID => $ConfigItemID,
            Comment      => $ConfigItemID . '%%' . $Param{Number},
        },
        UserID => $Param{UserID},
    );

    return $ConfigItemID;
}

=item ConfigItemDelete()

delete an existing config item

    my $True = $ConfigItemObject->ConfigItemDelete(
        ConfigItemID => 123,
        UserID       => 1,
    );

=cut

sub ConfigItemDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ConfigItemID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # remember config item data before delete
    my $ConfigItemData = $Self->ConfigItemGet(
        ConfigItemID => $Param{ConfigItemID},
    );

    #---------------------------------------------------------------------------
    # trigger ConfigItemDelete
    my $Result = $Self->PreEventHandler(
        Event => 'ConfigItemDelete',
        Data  => {
            ConfigItemID => $Param{ConfigItemID},
            Comment      => $Param{ConfigItemID},
            UserID       => $Param{UserID},
        },
        UserID => $Param{UserID},
    );
    if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Pre-ConfigItemDelete refused CI deletion.",
        );
        return $Result;
    }
    elsif ( ref($Result) eq 'HASH' ) {
        for my $ResultKey ( keys %{$Result} ) {
            $Param{$ResultKey} = $Result->{$ResultKey};
        }
    }
    #---------------------------------------------------------------------------

    # delete all links to this config item first, before deleting the versions
    return if !$Kernel::OM->Get('Kernel::System::LinkObject')->LinkDeleteAll(
        Object => 'ITSMConfigItem',
        Key    => $Param{ConfigItemID},
        UserID => $Param{UserID},
    );

    # delete existing versions
    $Self->VersionDelete(
        ConfigItemID => $Param{ConfigItemID},
        UserID       => $Param{UserID},
    );

    # get a list of all attachments
    my @ExistingAttachments = $Self->ConfigItemAttachmentList(
        ConfigItemID => $Param{ConfigItemID},
    );

    # delete all attachments of this config item
    FILENAME:
    for my $Filename (@ExistingAttachments) {

        # delete the attachment
        my $DeletionSuccess = $Self->ConfigItemAttachmentDelete(
            ConfigItemID => $Param{ConfigItemID},
            Filename     => $Filename,
            UserID       => $Param{UserID},
        );

        if ( !$DeletionSuccess ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unknown problem when deleting attachment $Filename of ConfigItem "
                    . "$Param{ConfigItemID}. Please check the VirtualFS backend for stale "
                    . "files!",
            );
        }
    }

    # trigger ConfigItemDelete event
    # this must be done before deleting the config item from the database,
    # because of a foreign key constraint in the configitem_history table
    $Self->EventHandler(
        Event => 'ConfigItemDelete',
        Data  => {
            ConfigItemID => $Param{ConfigItemID},
            Comment      => $Param{ConfigItemID},
            Number       => $ConfigItemData->{Number},
            Class        => $ConfigItemData->{Class},
        },
        UserID => $Param{UserID},
    );

    # delete config item
    my $Success = $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'DELETE FROM configitem WHERE id = ?',
        Bind => [ \$Param{ConfigItemID} ],
    );

    # delete the cache
    my $CacheKey = 'ConfigItemGet::ConfigItemID::' . $Param{ConfigItemID};
    $Kernel::OM->Get('Kernel::System::Cache')->Delete(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    return $Success;
}

=item ConfigItemAttachmentAdd()

adds an attachment to a config item

    my $Success = $ConfigItemObject->ConfigItemAttachmentAdd(
        ConfigItemID    => 1,
        Filename        => 'filename',
        Content         => 'content',
        ContentType     => 'text/plain',
        UserID          => 1,
    );

=cut

sub ConfigItemAttachmentAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ConfigItemID Filename Content ContentType UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    # write to virtual fs
    my $Success = $Kernel::OM->Get('Kernel::System::VirtualFS')->Write(
        Filename    => "ConfigItem/$Param{ConfigItemID}/$Param{Filename}",
        Mode        => 'binary',
        Content     => \$Param{Content},
        Preferences => {
            ContentID    => $Param{ContentID},
            ContentType  => $Param{ContentType},
            ConfigItemID => $Param{ConfigItemID},
            UserID       => $Param{UserID},
        },
    );

    # check for error
    if ($Success) {

        # trigger AttachmentAdd-Event
        $Self->EventHandler(
            Event => 'AttachmentAddPost',
            Data  => {
                %Param,
                ConfigItemID => $Param{ConfigItemID},
                Comment      => $Param{Filename},
                HistoryType  => 'AttachmentAdd',
            },
            UserID => $Param{UserID},
        );
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Cannot add attachment for config item $Param{ConfigItemID}",
        );

        return;
    }

    return 1;
}

=item ConfigItemAttachmentDelete()

Delete the given file from the virtual filesystem.

    my $Success = $ConfigItemObject->ConfigItemAttachmentDelete(
        ConfigItemID => 123,               # used in event handling, e.g. for logging the history
        Filename     => 'Projectplan.pdf', # identifies the attachment (together with the ConfigItemID)
        UserID       => 1,
    );

=cut

sub ConfigItemAttachmentDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ConfigItemID Filename UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    # add prefix
    my $Filename = 'ConfigItem/' . $Param{ConfigItemID} . '/' . $Param{Filename};

    # delete file
    my $Success = $Kernel::OM->Get('Kernel::System::VirtualFS')->Delete(
        Filename => $Filename,
    );

    # check for error
    if ($Success) {

        # trigger AttachmentDeletePost-Event
        $Self->EventHandler(
            Event => 'AttachmentDeletePost',
            Data  => {
                %Param,
                ConfigItemID => $Param{ConfigItemID},
                Comment      => $Param{Filename},
                HistoryType  => 'AttachmentDelete',
            },
            UserID => $Param{UserID},
        );
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Cannot delete attachment $Filename!",
        );

        return;
    }

    return $Success;
}

=item ConfigItemAttachmentGet()

This method returns information about one specific attachment.

    my $Attachment = $ConfigItemObject->ConfigItemAttachmentGet(
        ConfigItemID => 4,
        Filename     => 'test.txt',
    );

returns

    {
        Preferences => {
            AllPreferences => 'test',
        },
        Filename    => 'test.txt',
        Content     => 'content',
        ContentType => 'text/plain',
        Filesize    => '123 KBytes',
        Type        => 'attachment',
    }

=cut

sub ConfigItemAttachmentGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ConfigItemID Filename)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # add prefix
    my $Filename = 'ConfigItem/' . $Param{ConfigItemID} . '/' . $Param{Filename};

    # find all attachments of this config item
    my @Attachments = $Kernel::OM->Get('Kernel::System::VirtualFS')->Find(
        Filename    => $Filename,
        Preferences => {
            ConfigItemID => $Param{ConfigItemID},
        },
    );

    # return error if file does not exist
    if ( !@Attachments ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Message  => "No such attachment ($Filename)!",
            Priority => 'error',
        );
        return;
    }

    # get data for attachment
    my %AttachmentData = $Kernel::OM->Get('Kernel::System::VirtualFS')->Read(
        Filename => $Filename,
        Mode     => 'binary',
    );

    my $AttachmentInfo = {
        %AttachmentData,
        Filename    => $Param{Filename},
        Content     => ${ $AttachmentData{Content} },
        ContentType => $AttachmentData{Preferences}->{ContentType},
        Type        => 'attachment',
        Filesize    => $AttachmentData{Preferences}->{Filesize},
    };

    return $AttachmentInfo;
}

=item ConfigItemAttachmentList()

Returns an array with all attachments of the given config item.

    my @Attachments = $ConfigItemObject->ConfigItemAttachmentList(
        ConfigItemID => 123,
    );

returns

    @Attachments = (
        'filename.txt',
        'other_file.pdf',
    );

=cut

sub ConfigItemAttachmentList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ConfigItemID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ConfigItemID!',
        );

        return;
    }

    # find all attachments of this config item
    my @Attachments = $Kernel::OM->Get('Kernel::System::VirtualFS')->Find(
        Preferences => {
            ConfigItemID => $Param{ConfigItemID},
        },
    );

    for my $Filename (@Attachments) {

        # remove extra information from filename
        $Filename =~ s{ \A ConfigItem / \d+ / }{}xms;
    }

    return @Attachments;
}

=item ConfigItemAttachmentExists()

Checks if a file with a given filename exists.

    my $Exists = $ConfigItemObject->ConfigItemAttachmentExists(
        Filename => 'test.txt',
        ConfigItemID => 123,
        UserID   => 1,
    );

=cut

sub ConfigItemAttachmentExists {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Filename ConfigItemID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    return if !$Kernel::OM->Get('Kernel::System::VirtualFS')->Find(
        Filename => 'ConfigItem/' . $Param{ConfigItemID} . '/' . $Param{Filename},
    );

    return 1;
}

=item ConfigItemSearchExtended()

return a config item list as an array reference

    my $ConfigItemIDs = $ConfigItemObject->ConfigItemSearchExtended(
        Number       => 'The ConfigItem Number',  # (optional)
        Name         => 'The Name',               # (optional)
        ClassIDs     => [9, 8, 7, 6],             # (optional)
        DeplStateIDs => [1, 2, 3, 4],             # (optional)
        InciStateIDs => [1, 2, 3, 4],             # (optional)

        # config items with created time after ...
        ConfigItemCreateTimeNewerDate => '2006-01-09 00:00:01',  # (optional)
        # config items with created time before then ....
        ConfigItemCreateTimeOlderDate => '2006-01-19 23:59:59',  # (optional)

        # config items with changed time after ...
        ConfigItemChangeTimeNewerDate => '2006-01-09 00:00:01',  # (optional)
        # config items with changed time before then ....
        ConfigItemChangeTimeOlderDate => '2006-01-19 23:59:59',  # (optional)

        What => [                                                # (optional)
            # each array element is a and condition
            {
                # or condition in hash
                "[%]{'ElementA'}[%]{'ElementB'}[%]{'Content'}" => '%contentA%',
                "[%]{'ElementA'}[%]{'ElementC'}[%]{'Content'}" => '%contentA%',
            },
            {
                "[%]{'ElementA'}[%]{'ElementB'}[%]{'Content'}" => '%contentB%',
                "[%]{'ElementA'}[%]{'ElementC'}[%]{'Content'}" => '%contentB%',
            },
            {
                # use array reference if different content with same key was searched
                "[%]{'ElementA'}[%]{'ElementB'}[%]{'Content'}" => ['%contentC%', '%contentD%', '%contentE%'],
                "[%]{'ElementA'}[%]{'ElementC'}[%]{'Content'}" => ['%contentC%', '%contentD%', '%contentE%'],
            },
        ],

        PreviousVersionSearch => 1,  # (optional) default 0 (0|1)

        OrderBy => [ 'ConfigItemID', 'Number' ],                  # (optional)
        # default: [ 'ConfigItemID' ]
        # (ConfigItemID, Number, ClassID, DeplStateID, InciStateID,
        # CreateTime, CreateBy, ChangeTime, ChangeBy)

        # Additional information for OrderBy:
        # The OrderByDirection can be specified for each OrderBy attribute.
        # The pairing is made by the array indices.

        OrderByDirection => [ 'Down', 'Up' ],                    # (optional)
        # default: [ 'Down' ]
        # (Down | Up)

        Limit          => 122,  # (optional)
        UsingWildcards => 0,    # (optional) default 1
    );

=cut

sub ConfigItemSearchExtended {
    my ( $Self, %Param ) = @_;

    # set limit
    my $Limit = $Param{Limit};
    $Param{Limit} = undef;

    # config item search is required if one of these params is given
    my @ConfigItemSearchParams = (
        'ConfigItemCreateTimeNewerDate',
        'ConfigItemCreateTimeOlderDate',
        'ConfigItemChangeTimeNewerDate',
        'ConfigItemChangeTimeOlderDate',
    );

    # check, if config item search is required
    my %RequiredSearch;
    CONFIGITEMPARAM:
    for my $ConfigItemParam (@ConfigItemSearchParams) {
        next CONFIGITEMPARAM if !$Param{$ConfigItemParam};

        $RequiredSearch{ConfigItem} = 1;
        last CONFIGITEMPARAM;
    }

    # special handling for config item number
    # number 0 is allowed but not the empty string
    if ( defined $Param{Number} && $Param{Number} ne '' ) {
        $RequiredSearch{ConfigItem} = 1;
    }

    # version search is required if Name, What or PreviousVersionSearch is given
    if (
        ( defined $Param{Name} && $Param{Name} ne '' )
        || ( defined $Param{What} && $Param{What} ne '' )
        || $Param{PreviousVersionSearch}
    ) {
        $RequiredSearch{Version} = 1;
    }

    # version search is also required if sorting by name (fix for bug #7072)
    ORDERBY:
    for my $OrderBy ( @{ $Param{OrderBy} } ) {
        if ( $OrderBy eq 'Name' ) {
            $RequiredSearch{Version} = 1;
            last ORDERBY;
        }
    }

    # xml version search is required if What is given
    if ( IsArrayRefWithData( $Param{What} ) ) {
        $RequiredSearch{XMLVersion} = 1;
    }

    # use config item search as fallback
    if ( !%RequiredSearch ) {
        $RequiredSearch{ConfigItem} = 1;
    }

    # start config item search
    my %ConfigItemLists;
    if ( $RequiredSearch{ConfigItem} ) {

        # search config items
        $ConfigItemLists{ConfigItem} = $Self->ConfigItemSearch(%Param);

        return if !$ConfigItemLists{ConfigItem};
        return if ref $ConfigItemLists{ConfigItem} ne 'ARRAY';
        return [] if !@{ $ConfigItemLists{ConfigItem} };
    }

    # start version search
    if ( $RequiredSearch{Version} ) {

        # search versions
        $ConfigItemLists{Version} = $Self->VersionSearch(%Param);

        return if !$ConfigItemLists{Version};
        return if ref $ConfigItemLists{Version} ne 'ARRAY';
        return [] if !@{ $ConfigItemLists{Version} };
    }

    # start xml version search
    if ( $RequiredSearch{XMLVersion} ) {

        # search xml versions
        my $XMLVersionList = $Self->_XMLVersionSearch(%Param);

        return if !$XMLVersionList;
        return if ref $XMLVersionList ne 'HASH';
        return [] if !%{$XMLVersionList};

        # get config item ids
        my %ConfigItemListTmp;
        VERSIONID:
        for my $VersionID ( sort keys %{$XMLVersionList} ) {
            my $ConfigItemID = $Self->VersionConfigItemIDGet(
                VersionID => $VersionID,
            );

            next VERSIONID if !$ConfigItemID;

            $ConfigItemListTmp{$ConfigItemID} = 1;
        }

        # add ids to config item list
        $ConfigItemLists{XMLVersion} = \%ConfigItemListTmp;
    }

    # create the result list
    my @ResultList;
    if ( $RequiredSearch{ConfigItem} && $RequiredSearch{Version} ) {

        # build a lookup hash of all found configitem ids in $ConfigItemLists{ConfigItem}
        my %ConfigItemSeen = map { $_ => 1 } @{ $ConfigItemLists{ConfigItem} };

        # check all config item ids, we need to keep the sorting
        CONFIGITEMID:
        for my $ConfigItemID ( @{ $ConfigItemLists{Version} } ) {
            next CONFIGITEMID if !$ConfigItemSeen{$ConfigItemID};
            push @ResultList, $ConfigItemID;
        }
    }
    elsif ( $RequiredSearch{ConfigItem} ) {
        @ResultList = @{ $ConfigItemLists{ConfigItem} };
    }
    elsif ( $RequiredSearch{Version} ) {
        @ResultList = @{ $ConfigItemLists{Version} };
    }

    # consider the XML result
    if ( $RequiredSearch{XMLVersion} ) {
        @ResultList = grep { $ConfigItemLists{XMLVersion}->{$_} } @ResultList;
    }

    # consider limit
    if ( $Limit && $Limit < scalar @ResultList ) {

        # extract the limited ids
        $Limit--;
        @ResultList = @ResultList[ 0 .. $Limit ];
    }

    return \@ResultList;
}

=item ConfigItemSearch()

return a config item list as an array reference

    my $ConfigItemIDs = $ConfigItemObject->ConfigItemSearch(
        Number       => 'The ConfigItem Number',  # (optional)
        ClassIDs     => [9, 8, 7, 6],             # (optional)
        DeplStateIDs => [1, 2, 3, 4],             # (optional)
        InciStateIDs => [1, 2, 3, 4],             # (optional)
        CreateBy     => [1, 2, 3],                # (optional)
        ChangeBy     => [3, 2, 1],                # (optional)

        # config items with created time after ...
        ConfigItemCreateTimeNewerDate => '2006-01-09 00:00:01',  # (optional)
        # config items with created time before then ....
        ConfigItemCreateTimeOlderDate => '2006-01-19 23:59:59',  # (optional)

        # config items with changed time after ...
        ConfigItemChangeTimeNewerDate => '2006-01-09 00:00:01',  # (optional)
        # config items with changed time before then ....
        ConfigItemChangeTimeOlderDate => '2006-01-19 23:59:59',  # (optional)

        OrderBy => [ 'ConfigItemID', 'Number' ],                  # (optional)
        # default: [ 'ConfigItemID' ]
        # (ConfigItemID, Number, ClassID, DeplStateID, InciStateID,
        # CreateTime, CreateBy, ChangeTime, ChangeBy)

        # Additional information for OrderBy:
        # The OrderByDirection can be specified for each OrderBy attribute.
        # The pairing is made by the array indices.

        OrderByDirection => [ 'Down', 'Up' ],                    # (optional)
        # default: [ 'Down' ]
        # (Down | Up)

        Limit          => 122,  # (optional)
        UsingWildcards => 0,    # (optional) default 1
    );

=cut

sub ConfigItemSearch {
    my ( $Self, %Param ) = @_;

    # verify that all passed array parameters contain an arrayref
    ARGUMENT:
    for my $Argument (
        qw(
        OrderBy
        OrderByDirection
        )
    ) {
        if ( !defined $Param{$Argument} ) {
            $Param{$Argument} ||= [];

            next ARGUMENT;
        }

        if ( ref $Param{$Argument} ne 'ARRAY' ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "$Argument must be an array reference!",
            );
            return;
        }
    }

    # define order table
    my %OrderByTable = (
        ConfigItemID => 'id',
        Number       => 'configitem_number',
        ClassID      => 'class_id',
        DeplStateID  => 'cur_depl_state_id',
        InciStateID  => 'cur_inci_state_id',
        CreateTime   => 'create_time',
        CreateBy     => 'create_by',
        ChangeTime   => 'change_time',
        ChangeBy     => 'change_by',
    );

    # do default sort if item not used
    my $Match = 0;
    for my $OrderBy ( @{ $Param{OrderBy} } ) {
        next if ( !$OrderByTable{$OrderBy} );
        $Match = 1;
    }
    if ( !$Match ) {
        @{ $Param{OrderBy} } = ('Number');
    }

    # check if OrderBy contains only unique valid values
    my %OrderBySeen;
    ORDERBY:
    for my $OrderBy ( @{ $Param{OrderBy} } ) {

        next ORDERBY if $OrderBy eq 'Name';

        if ( !$OrderBy || !$OrderByTable{$OrderBy} || $OrderBySeen{$OrderBy} ) {

            # found an error
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "OrderBy contains invalid value '$OrderBy' "
                    . 'or the value is used more than once!',
            );
            return;
        }

        # remember the value to check if it appears more than once
        $OrderBySeen{$OrderBy} = 1;
    }

    # check if OrderByDirection array contains only 'Up' or 'Down'
    DIRECTION:
    for my $Direction ( @{ $Param{OrderByDirection} } ) {

        # only 'Up' or 'Down' allowed
        next DIRECTION if $Direction eq 'Up';
        next DIRECTION if $Direction eq 'Down';

        # found an error
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "OrderByDirection can only contain 'Up' or 'Down'!",
        );
        return;
    }

    # set default values
    if ( !defined $Param{UsingWildcards} ) {
        $Param{UsingWildcards} = 1;
    }

    # get like escape string needed for some databases (e.g. oracle)
    my $LikeEscapeString = $Kernel::OM->Get('Kernel::System::DB')->GetDatabaseFunction('LikeEscapeString');

    # assemble the ORDER BY clause
    my @SQLOrderBy;
    my $Count = 0;
    ORDERBY:
    for my $OrderBy ( @{ $Param{OrderBy} } ) {

        next ORDERBY if $OrderBy eq 'Name';

        # set the default order direction
        my $Direction = 'DESC';

        # add the given order direction
        if ( $Param{OrderByDirection}->[$Count] ) {
            if ( $Param{OrderByDirection}->[$Count] eq 'Up' ) {
                $Direction = 'ASC';
            }
            elsif ( $Param{OrderByDirection}->[$Count] eq 'Down' ) {
                $Direction = 'DESC';
            }
        }

        # add SQL
        push @SQLOrderBy, "$OrderByTable{$OrderBy} $Direction";

    }
    continue {
        $Count++;
    }

    # if there is a possibility that the ordering is not determined
    # we add an ascending ordering by id
    if ( !grep { $_ eq 'ConfigItemID' } ( @{ $Param{OrderBy} } ) ) {
        push @SQLOrderBy, "$OrderByTable{ConfigItemID} ASC";
    }

    # add number to sql where array
    my @SQLWhere;
    if ( defined $Param{Number} && $Param{Number} ne '' ) {

        # quote
        $Param{Number} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{Number} );

        if ( $Param{UsingWildcards} ) {

            # prepare like string
            $Self->_PrepareLikeString( \$Param{Number} );

            push @SQLWhere,
                "LOWER(configitem_number) LIKE LOWER('$Param{Number}') $LikeEscapeString";
        }
        else {
            push @SQLWhere, "LOWER(configitem_number) = LOWER('$Param{Number}')";
        }
    }

    # set array params
    my %ArrayParams = (
        ClassIDs     => 'class_id',
        DeplStateIDs => 'cur_depl_state_id',
        InciStateIDs => 'cur_inci_state_id',
        CreateBy     => 'create_by',
        ChangeBy     => 'change_by',
    );

    ARRAYPARAM:
    for my $ArrayParam ( sort keys %ArrayParams ) {

        next ARRAYPARAM if !$Param{$ArrayParam};

        if ( ref $Param{$ArrayParam} ne 'ARRAY' ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "$ArrayParam must be an array reference!",
            );
            return;
        }

        next ARRAYPARAM if !@{ $Param{$ArrayParam} };

        # quote as integer
        for my $OneParam ( @{ $Param{$ArrayParam} } ) {
            $OneParam = $Kernel::OM->Get('Kernel::System::DB')->Quote( $OneParam, 'Integer' );
        }

        # create string
        my $InString = join q{, }, @{ $Param{$ArrayParam} };

        next ARRAYPARAM if $InString eq '';

        push @SQLWhere, "$ArrayParams{ $ArrayParam } IN ($InString)";
    }

    # set time params
    my %TimeParams = (
        ConfigItemCreateTimeNewerDate => 'create_time >=',
        ConfigItemCreateTimeOlderDate => 'create_time <=',
        ConfigItemChangeTimeNewerDate => 'change_time >=',
        ConfigItemChangeTimeOlderDate => 'change_time <=',
    );

    TIMEPARAM:
    for my $TimeParam ( sort keys %TimeParams ) {

        next TIMEPARAM if !$Param{$TimeParam};

        if ( $Param{$TimeParam} !~ m{ \A \d\d\d\d-\d\d-\d\d \s \d\d:\d\d:\d\d \z }xms ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Invalid date format found!",
            );
            return;
        }

        # quote
        $Param{$TimeParam} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{$TimeParam} );

        push @SQLWhere, "$TimeParams{ $TimeParam } '$Param{ $TimeParam }'";
    }

    # create where string
    my $WhereString = @SQLWhere ? ' WHERE ' . join q{ AND }, @SQLWhere : '';

    # set limit
    if ( $Param{Limit} ) {
        $Param{Limit} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{Limit}, 'Integer' );
    }

    my $SQL = "SELECT id FROM configitem $WhereString ";

    # add the ORDER BY clause
    if (@SQLOrderBy) {
        $SQL .= 'ORDER BY ';
        $SQL .= join ', ', @SQLOrderBy;
        $SQL .= ' ';
    }

    # ask database
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL   => $SQL,
        Limit => $Param{Limit},
    );

    # fetch the result
    my @ConfigItemList;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        push @ConfigItemList, $Row[0];
    }

    return \@ConfigItemList;
}

=item ConfigItemLookup()

This method does a lookup for a configitem. If a configitem id is given,
it returns the number of the configitem. If a configitem number is given,
the appropriate id is returned.

    my $Number = $ConfigItemObject->ConfigItemLookup(
        ConfigItemID => 1234,
    );

    my $ID = $ConfigItemObject->ConfigItemLookup(
        ConfigItemNumber => 1000001,
    );

=cut

sub ConfigItemLookup {
    my ( $Self, %Param ) = @_;

    my ($Key) = grep { $Param{$_} } qw(ConfigItemID ConfigItemNumber);

    # check for needed stuff
    if ( !$Key ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ConfigItemID or ConfigItemNumber!',
        );
        return;
    }

    # if result is cached return that result
    return $Self->{Cache}->{ConfigItemLookup}->{$Key}->{ $Param{$Key} }
        if $Self->{Cache}->{ConfigItemLookup}->{$Key}->{ $Param{$Key} };

    # set the appropriate SQL statement
    my $SQL = 'SELECT configitem_number FROM configitem WHERE id = ?';

    if ( $Key eq 'ConfigItemNumber' ) {
        $SQL = 'SELECT id FROM configitem WHERE configitem_number = ?';
    }

    # fetch the requested value
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL   => $SQL,
        Bind  => [ \$Param{$Key} ],
        Limit => 1,
    );

    my $Value;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $Value = $Row[0];
    }

    $Self->{Cache}->{ConfigItemLookup}->{$Key}->{ $Param{$Key} } = $Value;

    return $Value;
}

=item UniqueNameCheck()

This method checks all already existing config items, whether the given name does already exist
within the same config item class or amongst all classes, depending on the SysConfig value of
UniqueCIName::UniquenessCheckScope (Class or Global).

This method requires 3 parameters: ConfigItemID, Name and Class
"ConfigItemID"  is the ID of the ConfigItem, which is to be checked for uniqueness
"Name"          is the config item name to be checked for uniqueness
"ClassID"       is the ID of the config item's class

All parameters are mandatory.

my $DuplicateNames = $ConfigItemObject->UniqueNameCheck(
    ConfigItemID => '73'
    Name         => 'PC#005',
    ClassID      => '32',
);

The given name is not unique
my $NameDuplicates = [ 5, 35, 48, ];    # IDs of ConfigItems with the same name

The given name is unique
my $NameDuplicates = [];

=cut

sub UniqueNameCheck {
    my ( $Self, %Param ) = @_;

    # check for needed stuff
    for my $Needed (qw(ConfigItemID Name ClassID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Missing parameter $Needed!",
            );
            return;
        }
    }

    # check ConfigItemID param for valid format
    if (
        !IsInteger( $Param{ConfigItemID} )
        && ( IsStringWithData( $Param{ConfigItemID} ) && $Param{ConfigItemID} ne 'NEW' )
    ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "The ConfigItemID parameter needs to be an integer or 'NEW'",
        );
        return;
    }

    # check Name param for valid format
    if ( !IsStringWithData( $Param{Name} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "The Name parameter needs to be a string!",
        );
        return;
    }

    # check ClassID param for valid format
    if ( !IsInteger( $Param{ClassID} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "The ClassID parameter needs to be an integer",
        );
        return;
    }

    # get class list
    my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    # check class list for validity
    if ( !IsHashRefWithData($ClassList) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unable to retrieve a valid class list!",
        );
        return;
    }

    # get the class name from the class list
    my $Class = $ClassList->{ $Param{ClassID} };

    # check class for validity
    if ( !IsStringWithData($Class) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unable to determine a config item class using the given ClassID!",
        );
        return;
    }
    elsif ( $Kernel::OM->Get('Kernel::Config')->{Debug} > 0 ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'debug',
            Message  => "Resolved ClassID $Param{ClassID} to class $Class",
        );
    }

    # get the uniqueness scope from SysConfig
    my $Scope = $Kernel::OM->Get('Kernel::Config')->Get('UniqueCIName::UniquenessCheckScope');

    # check scope for validity
    if ( !IsStringWithData($Scope) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "The configuration of UniqueCIName::UniquenessCheckScope is invalid!",
        );
        return;
    }

    if ( $Scope ne 'global' && $Scope ne 'class' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "UniqueCIName::UniquenessCheckScope is $Scope, but must be either "
                . "'global' or 'class'!",
        );
        return;
    }

    if ( $Kernel::OM->Get('Kernel::Config')->{Debug} > 0 ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'debug',
            Message  => "The scope for checking the uniqueness is $Scope",
        );
    }

    my %SearchCriteria;

    # add the config item class to the search criteria if the uniqueness scope is not global
    if ( $Scope ne 'global' ) {
        $SearchCriteria{ClassIDs} = [ $Param{ClassID} ];
    }

    $SearchCriteria{Name} = $Param{Name};

    # search for a config item matching the given name
    my $ConfigItem = $Self->ConfigItemSearchExtended(%SearchCriteria);

    # remove the provided ConfigItemID from the results, otherwise the duplicate check would fail
    # because the ConfigItem itself is found as duplicate
    my @Duplicates = map {$_} grep { $_ ne $Param{ConfigItemID} } @{$ConfigItem};

    # if a config item was found, the given name is not unique
    # if no config item was found, the given name is unique

    # return the result of the config item search for duplicates
    return \@Duplicates;
}

=item CurInciStateRecalc()

recalculates the current incident state of this config item and all linked config items

    my $Success = $ConfigItemObject->CurInciStateRecalc(
        ConfigItemID => 123,
    );

=cut

sub CurInciStateRecalc {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ConfigItemID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ConfigItemID!',
        );
        return;
    }

    # get incident link types and directions from config
    my $IncidentLinkTypeDirection = $Kernel::OM->Get('Kernel::Config')->Get('ITSM::Core::IncidentLinkTypeDirection');

    # to store the new incident state for CIs
    # calculated from all incident link types
    my %NewConfigItemIncidentState;

    # to store the relation between services and linked CIs
    my %ServiceCIRelation;

    # remember the scanned config items
    my %ScannedConfigItemIDs;

    # find all config items with an incident state
    $Self->_FindInciConfigItems(
        ConfigItemID              => $Param{ConfigItemID},
        IncidentLinkTypeDirection => $IncidentLinkTypeDirection,
        ScannedConfigItemIDs      => \%ScannedConfigItemIDs,
    );

    # calculate the new CI incident state for each configured linktype
    LINKTYPE:
    for my $LinkType ( sort keys %{$IncidentLinkTypeDirection} ) {

        # get the direction
        my $LinkDirection = $IncidentLinkTypeDirection->{$LinkType};

        # investigate all config items with a warning state
        CONFIGITEMID:
        for my $ConfigItemID ( sort keys %ScannedConfigItemIDs ) {

            # investigate only config items with an incident state
            next CONFIGITEMID if $ScannedConfigItemIDs{$ConfigItemID}->{Type} ne 'incident';

            $Self->_FindWarnConfigItems(
                ConfigItemID         => $ConfigItemID,
                LinkType             => $LinkType,
                Direction            => $LinkDirection,
                NumberOfLinkTypes    => scalar keys %{$IncidentLinkTypeDirection},
                ScannedConfigItemIDs => \%ScannedConfigItemIDs,
            );
        }

        CONFIGITEMID:
        for my $ConfigItemID ( sort keys %ScannedConfigItemIDs ) {

            # extract incident state type
            my $InciStateType = $ScannedConfigItemIDs{$ConfigItemID}->{Type};

            # find all linked services of this CI
            my %LinkedServiceIDs = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkKeyList(
                Object1   => 'ITSMConfigItem',
                Key1      => $ConfigItemID,
                Object2   => 'Service',
                State     => 'Valid',
                Type      => $LinkType,
                Direction => $LinkDirection,
                UserID    => 1,
            );

            SERVICEID:
            for my $ServiceID ( sort keys %LinkedServiceIDs ) {

                # remember the CIs that are linked with this service
                push @{ $ServiceCIRelation{$ServiceID} }, $ConfigItemID;
            }

            next CONFIGITEMID if $InciStateType eq 'incident';

            # if nothing has been set already or if the currently set incident state is 'operational'
            # ('operational' can always be overwritten)
            if (
                !$NewConfigItemIncidentState{$ConfigItemID}
                || $NewConfigItemIncidentState{$ConfigItemID} eq 'operational'
            ) {
                $NewConfigItemIncidentState{$ConfigItemID} = $InciStateType;
            }
        }
    }

    # get the incident state list of warnings
    my $WarnStateList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class       => 'ITSM::Core::IncidentState',
        Preferences => {
            Functionality => 'warning',
        },
    );
    my %ReverseWarnStateList = reverse %{$WarnStateList};
    my @SortedWarnList       = sort keys %ReverseWarnStateList;
    my $WarningStateID       = $ReverseWarnStateList{Warning} || $ReverseWarnStateList{ $SortedWarnList[0] };
    my $CacheObject          = $Kernel::OM->Get('Kernel::System::Cache');

    # set the new current incident state for CIs
    CONFIGITEMID:
    for my $ConfigItemID ( sort keys %NewConfigItemIncidentState ) {

        # get new incident state type (can only be 'operational' or 'warning')
        my $InciStateType = $NewConfigItemIncidentState{$ConfigItemID};

        # get last version
        my $LastVersion = $Self->VersionGet(
            ConfigItemID => $ConfigItemID,
            XMLDataGet   => 0,
        );

        my $CurInciStateID;
        if ( $InciStateType eq 'warning' ) {

            # check the current incident state type is in 'incident'
            # then we do not want to change it to warning
            next CONFIGITEMID if $LastVersion->{InciStateType} eq 'incident';

            $CurInciStateID = $WarningStateID;
        }
        elsif ( $InciStateType eq 'operational' ) {
            $CurInciStateID = $LastVersion->{InciStateID};
        }

        # update current incident state
        $Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL  => 'UPDATE configitem SET cur_inci_state_id = ? WHERE id = ?',
            Bind => [ \$CurInciStateID, \$ConfigItemID ],
        );

        # delete the cache
        my $CacheKey = 'ConfigItemGet::ConfigItemID::' . $ConfigItemID;
        $CacheObject->Delete(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );

        # delete affected caches for ConfigItemID
        $CacheKey = 'VersionGet::ConfigItemID::' . $ConfigItemID . '::XMLData::';
        for my $XMLData (qw(0 1)) {
            $CacheObject->Delete(
                Type => $Self->{CacheType},
                Key  => $CacheKey . $XMLData,
            );
        }
        $CacheObject->Delete(
            Type => $Self->{CacheType},
            Key  => 'VersionNameGet::ConfigItemID::' . $ConfigItemID,
        );

        # delete affected caches for last version
        my $VersionList = $Self->VersionList(
            ConfigItemID => $ConfigItemID,
        );
        my $VersionID = $VersionList->[-1];
        $CacheKey = 'VersionGet::VersionID::' . $VersionID . '::XMLData::';
        for my $XMLData (qw(0 1)) {
            $CacheObject->Delete(
                Type => $Self->{CacheType},
                Key  => $CacheKey . $XMLData,
            );
        }
        $CacheObject->Delete(
            Type => $Self->{CacheType},
            Key  => 'VersionNameGet::VersionID::' . $VersionID,
        );
    }

    # set the current incident state type for each service (influenced by linked CIs)
    SERVICEID:
    for my $ServiceID ( sort keys %ServiceCIRelation ) {

        # set default incident state type
        my $CurInciStateTypeFromCIs = 'operational';

        # get the unique config item ids which are direcly linked to this service
        my %UniqueConfigItemIDs = map { $_ => 1 } @{ $ServiceCIRelation{$ServiceID} };

        # investigate the current incident state of each config item
        CONFIGITEMID:
        for my $ConfigItemID ( sort keys %UniqueConfigItemIDs ) {

            # get config item data
            my $ConfigItemData = $Self->ConfigItemGet(
                ConfigItemID => $ConfigItemID,
                Cache        => 0,
            );

            next CONFIGITEMID if $ConfigItemData->{CurDeplStateType} ne 'productive';
            next CONFIGITEMID if $ConfigItemData->{CurInciStateType} eq 'operational';

            # check if service must be set to 'warning'
            if ( $ConfigItemData->{CurInciStateType} eq 'warning' ) {
                $CurInciStateTypeFromCIs = 'warning';
                next CONFIGITEMID;
            }

            # check if service must be set to 'incident'
            if ( $ConfigItemData->{CurInciStateType} eq 'incident' ) {
                $CurInciStateTypeFromCIs = 'incident';
                last CONFIGITEMID;
            }
        }

        # update the current incident state type from CIs of the service
        $Kernel::OM->Get('Kernel::System::Service')->ServicePreferencesSet(
            ServiceID => $ServiceID,
            Key       => 'CurInciStateTypeFromCIs',
            Value     => $CurInciStateTypeFromCIs,
            UserID    => 1,
        );
    }

    return 1;
}

# The following methods are meant to ease the handling of the XML-LIKE data hash.
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
    ) {
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
                my $Value = $Self->XMLValueLookup(
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
    ) {
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

=item GetAttributeDefByTagKey()

Returns chosen CI attribute definition, for a given tag key.
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
    return if (
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
                return %{$Item};
            }

            next COUNTER if !$Item->{Sub};

            # recurse if subsection available...
            my $SubResult = $Self->GetAttributeDefByTagKey(
                TagKey        => $Param{TagKey},
                XMLDefinition => $Item->{Sub},
                XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
            );

            if ( $SubResult && ref($SubResult) eq 'HASH' ) {
                return %{$SubResult};
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
            my $Content = $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content} || '';
            next COUNTER if !$Content;

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
        || !length( $Param{NewContent} )
        || ( !$Param{XMLData} )
        || ( !$Param{XMLDefinition} )
        || ( ref $Param{XMLData} ne 'HASH' )
        || ( ref $Param{XMLDefinition} ne 'ARRAY' )
    ) {
        return 0;
    }

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # get the value...
            if ( $Item->{Key} eq $Param{KeyName} ) {
                $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content} = $Param{NewContent};
            }

            # no content then stop loop...
            last COUNTER if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

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

=item VersionCount()

    Returns the number of versions for a given config item.

    $ConfigItemObject->VersionCount(
        ConfigItemID => 123,
    );

=cut

sub VersionCount {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    return if ( !$Param{ConfigItemID} );

    my $VersionList = $Self->VersionList(
        ConfigItemID => $Param{ConfigItemID},
    );
    return if ( !$VersionList || ref($VersionList) ne 'ARRAY' );

    $Result = ( scalar( @{$VersionList} ) || 0 );

    return $Result;
}

=item CountLinkedObjects()

Returns the number of objects linked with a given ticket.

    my $Result = $ConfigItemObject->CountLinkedObjects(
        ConfigItemID => 123,
        UserID => 1
    );

=cut

sub CountLinkedObjects {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    return if ( !$Param{ConfigItemID} );

    my $LinkObject = $Self->{LinkObject} || undef;

    if ( !$LinkObject ) {
        $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');
    }

    return '' if !$LinkObject;

    my %PossibleObjectsList = $LinkObject->PossibleObjectsList(
        Object => 'ITSMConfigItem',
        UserID => $Param{UserID} || 1,
    );
    for my $CurrObject ( keys(%PossibleObjectsList) ) {
        my %LinkList = $LinkObject->LinkKeyList(
            Object1 => 'ITSMConfigItem',
            Key1    => $Param{ConfigItemID},
            Object2 => $CurrObject,
            State   => 'Valid',
            UserID  => 1,
        );

        $Result = $Result + ( scalar( keys(%LinkList) ) || 0 );
    }

    return $Result;
}

=begin Internal:

=item _FindInciConfigItems()

find all config items with an incident state

    $ConfigItemObject->_FindInciConfigItems(
        ConfigItemID              => $ConfigItemID,
        IncidentLinkTypeDirection => $IncidentLinkTypeDirection,
        ScannedConfigItemIDs     => \%ScannedConfigItemIDs,
    );

=cut

sub _FindInciConfigItems {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{ConfigItemID};

    # ignore already scanned ids (infinite loop protection)
    return if $Param{ScannedConfigItemIDs}->{ $Param{ConfigItemID} };

    $Param{ScannedConfigItemIDs}->{ $Param{ConfigItemID} }->{Type} = 'operational';

    # add own config item id to list of linked config items
    my %ConfigItemIDs = (
        $Param{ConfigItemID} => 1,
    );

    LINKTYPE:
    for my $LinkType ( sort keys %{ $Param{IncidentLinkTypeDirection} } ) {

        # find all linked config items (childs)
        my %LinkedConfigItemIDs = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkKeyList(
            Object1 => 'ITSMConfigItem',
            Key1    => $Param{ConfigItemID},
            Object2 => 'ITSMConfigItem',
            State   => 'Valid',
            Type    => $LinkType,

            # Direction must ALWAYS be 'Both' here as we need to include
            # all linked CIs that could influence this one!
            Direction => 'Both',

            UserID => 1,
        );

        # remember the config item ids
        %ConfigItemIDs = ( %ConfigItemIDs, %LinkedConfigItemIDs );
    }

    CONFIGITEMID:
    for my $ConfigItemID ( sort keys %ConfigItemIDs ) {

        # get config item data
        my $ConfigItem = $Self->ConfigItemGet(
            ConfigItemID => $ConfigItemID,
            Cache        => 0,
        );

        # set incident state
        if ( $ConfigItem->{CurInciStateType} eq 'incident' ) {
            $Param{ScannedConfigItemIDs}->{$ConfigItemID}->{Type} = 'incident';
            next CONFIGITEMID;
        }

        # start recursion
        $Self->_FindInciConfigItems(
            ConfigItemID              => $ConfigItemID,
            IncidentLinkTypeDirection => $Param{IncidentLinkTypeDirection},
            ScannedConfigItemIDs      => $Param{ScannedConfigItemIDs},
        );
    }

    return 1;
}

=item _FindWarnConfigItems()

find all config items with a warning

    $ConfigItemObject->_FindWarnConfigItems(
        ConfigItemID         => $ConfigItemID,
        LinkType             => $LinkType,
        Direction            => $LinkDirection,
        NumberOfLinkTypes    => 2,
        ScannedConfigItemIDs => $ScannedConfigItemIDs,
    );

=cut

sub _FindWarnConfigItems {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{ConfigItemID};

    my $IncidentCount = 0;
    for my $ConfigItemID ( sort keys %{ $Param{ScannedConfigItemIDs} } ) {
        if (
            $Param{ScannedConfigItemIDs}->{$ConfigItemID}->{Type}
            && $Param{ScannedConfigItemIDs}->{$ConfigItemID}->{Type} eq 'incident'
        ) {
            $IncidentCount++;
        }
    }

# ignore already scanned ids (infinite loop protection)
# it is ok that a config item is investigated as many times as there are configured link types * number of incident config iteems
    if (
        $Param{ScannedConfigItemIDs}->{ $Param{ConfigItemID} }->{FindWarn}
        && $Param{ScannedConfigItemIDs}->{ $Param{ConfigItemID} }->{FindWarn} >= ( $Param{NumberOfLinkTypes} * $IncidentCount )
    ) {
        return;
    }

    $Self->{Direction} = $Kernel::OM->Get('Kernel::Config')->Get('ITSMConfigItem::CILinkDirection') || 'Both';

    # increase the visit counter
    $Param{ScannedConfigItemIDs}->{ $Param{ConfigItemID} }->{FindWarn}++;

    # find all linked config items
    my %LinkedConfigItemIDs = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkKeyList(
        Object1   => 'ITSMConfigItem',
        Key1      => $Param{ConfigItemID},
        Object2   => 'ITSMConfigItem',
        State     => 'Valid',
        Type      => $Param{LinkType},
        Direction => $Param{Direction},
        UserID    => 1,
    );

    CONFIGITEMID:
    for my $ConfigItemID ( sort keys %LinkedConfigItemIDs ) {

        # start recursion
        $Self->_FindWarnConfigItems(
            ConfigItemID         => $ConfigItemID,
            LinkType             => $Param{LinkType},
            Direction            => $Param{Direction},
            NumberOfLinkTypes    => $Param{NumberOfLinkTypes},
            ScannedConfigItemIDs => $Param{ScannedConfigItemIDs},
        );

        next CONFIGITEMID
            if $Param{ScannedConfigItemIDs}->{$ConfigItemID}->{Type}
            && $Param{ScannedConfigItemIDs}->{$ConfigItemID}->{Type} eq 'incident';

        # set warning state
        $Param{ScannedConfigItemIDs}->{$ConfigItemID}->{Type} = 'warning';
    }

    return 1;
}

=item _PrepareLikeString()

internal function to prepare like strings

    $ConfigItemObject->_PrepareLikeString( $StringRef );

=cut

sub _PrepareLikeString {
    my ( $Self, $Value ) = @_;

    return if !$Value;
    return if ref $Value ne 'SCALAR';

    # Quote
    ${$Value} = $Kernel::OM->Get('Kernel::System::DB')->Quote( ${$Value}, 'Like' );

    # replace * with %
    ${$Value} =~ s{ \*+ }{%}xmsg;

    return;
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
