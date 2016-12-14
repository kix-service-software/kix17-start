# --
# Kernel/System/QueuesGroupsRoles.pm - QueuesGroupsRoles system module
# Copyright (C) 2006-2015 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
# * Anna(dot)Litvinova(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Frank(dot)Oberender(at)cape(dash)it(dot)de
# * Thomas(dot)Lange(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::QueuesGroupsRoles;

use strict;
use warnings;
use Kernel::System::EmailParser;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Group',
    'Kernel::System::Queue',
    'Kernel::System::Log',
    'Kernel::System::Valid',
    'Kernel::System::SystemAddress',
    'Kernel::System::CSV',
);

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = {};
    bless( $Self, $Type );

    #$Self->{EmailParserObject}   ||= Kernel::System::EmailParser->new( 
        #%{$Self}, 
        #Mode => 'Standalone', 
    #);
    
    return $Self;
}

sub Upload {
    my ( $Self, %Param ) = @_;
    my @Content = $Param{Content};

    my $QGRConfig   = $Kernel::OM->Get('Kernel::Config')->Get("QueuesGroupsRoles");
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');
    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');
    my $EmailParserObject  = Kernel::System::EmailParser->new( 
        %{$Self}, 
        Mode => 'Standalone', 
    );
    
    my %Queues = $QueueObject->QueueList( Valid => 0 );
    my %Groups = $GroupObject->GroupList( Valid => 0 );
    my %Roles  = $GroupObject->RoleList( Valid => 0 );
    my %RevRoleList = reverse (%Roles);
    my %RevGroupList = reverse (%Groups);
    my %RevQueueList = reverse (%Queues);

    my $lineCounter  = 0;
    my @currLine     = ();
    my @HeadlineKeys = qw{
        SalutationID SignatureID FollowUpID FollowUpLock UnlockTimeout
        FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify
        SolutionTime SolutionNotify Calendar Validity SystemAddress
    };
    my %HeadlineValues = ();
    my @RoleNames      = ();
    my @RoleIDs        = ();
    my $currGroup      = undef;
    my $currQueue      = undef;
    my $Message        = "";

    for my $currLine ( @{ $Param{Content} } ) {

        $lineCounter++;
        $currLine =~ s/"//g;

        if ( $lineCounter == 1 ) {
            @currLine = split( /;/, $currLine );
            my $Forget1 = shift(@currLine);
            my $Forget2 = shift(@currLine);

            # get Non-Row headlines...
            for my $CurrKey (@HeadlineKeys) {

                #NOTE: headlines ar not used any further, the order of the columns is important!
                $HeadlineValues{$CurrKey} = shift(@currLine);
            }

            # get role names...
            @RoleNames = @currLine;

            # create roles if not already there...
            for my $Role (@RoleNames) {
                # using rev-list because there is no Silent option...
                my $RoleID = $RevRoleList{$Role};
                if ( !$RoleID ) {
                    $RoleID = $GroupObject->RoleAdd(
                        Name    => $Role,
                        ValidID => 1,
                        UserID  => 1,
                    );
                }
                $RevRoleList{$Role} = $RoleID;
                push( @RoleIDs, $RoleID );
            }
        }

        # following lines...
        else {
            @currLine  = split( /;/, $currLine );
            $currQueue = shift(@currLine);
            $currGroup = shift(@currLine);
            my %QueueAttributes = ();
            for my $CurrKey (@HeadlineKeys) {
                $QueueAttributes{$CurrKey} = shift(@currLine);
            }

            $Message = "QGR-Import: Processing line $lineCounter...";
            if ( $Param{MessageToSTDERR} ) {
                print STDERR "\n" . $Message;
            }
            else {
                $LogObject->Log(
                    Priority => 'notice',
                    Message  => $Message,
                );
            }

            #-----------------------------------------------------------------------
            # handle group....
            my $GroupID = 0;
            if ($currGroup) {
                # using rev-list because there is no Silent option...
                $GroupID = $RevGroupList{$currGroup};
            }
            if ( !$GroupID && $currGroup ) {
                $Message = "QGR-Import: Creating GROUP=<$currGroup>...";
                if ( $Param{MessageToSTDERR} ) {
                    print STDERR "\n" . $Message;
                }
                else {
                    $LogObject->Log(
                        Priority => 'notice',
                        Message  => $Message,
                    );
                }

                $GroupID = $GroupObject->GroupAdd(
                    Name    => $currGroup,
                    ValidID => 1,
                    UserID  => 1,
                );
                $RevGroupList{$currGroup} = $GroupID;
            }

            #-----------------------------------------------------------------------
            # handle queue...
            if ($currQueue) {
                # using rev-list because there is no Silent option...
                my $QueueID = $RevQueueList{$currQueue};

                # check validity string or id...
                my $ValidID = $QueueAttributes{Validity};
                if ( $ValidID !~ /\d+/ ) {
                    my %ValidList        = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();
                    my %ReverseValidList = reverse(%ValidList);
                    $ValidID = $ReverseValidList{ $QueueAttributes{Validity} };
                }

                #check system address string or id...
                my $SystemAddress         = $QueueAttributes{SystemAddress} || '';
                my $SystemAddressID       = $SystemAddress;
                my $SystemAddressEmail    = "";
                my $SystemAddressRealName = "";

                if ( $SystemAddress && $SystemAddress !~ /^\d+$/ ) {
                    $SystemAddressEmail = $EmailParserObject->GetEmailAddress(
                        Email => $SystemAddress,
                    );
                    $SystemAddressRealName = $EmailParserObject->GetRealname(
                        Email => $SystemAddress,
                    );
                    # if no real name given create one out of email (cut at @)...
                    if( !$SystemAddressRealName ) {
                        $SystemAddressRealName = $SystemAddress;
                        $SystemAddressRealName =~ s/\@.*//g;
                    }
                }

                # create or lookup new SystemAddress...
                if ( $SystemAddress && $SystemAddress !~ /^\d+$/ ) {
                    my %List    = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressList();
                    my $FoundID = 0;
                    for my $CurrKey ( keys(%List) ) {
                        if ( $List{$CurrKey} =~ /$SystemAddressEmail$/ ) {
                            $FoundID = $CurrKey;
                            last;
                        }
                    }
                    if ( !$FoundID ) {
                        $SystemAddressID = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressAdd(
                            Name     => $SystemAddressEmail,
                            Realname => $SystemAddressRealName,
                            ValidID  => 1,
                            # NOTE: the queue does not exist yet, so we use QueueID 1...
                            QueueID  => 1,
                            Comment  => '',
                            UserID   => 1,
                        );
                    }
                    else {
                        $SystemAddressID = $FoundID;
                    }
                }
                
                # update/create queue...
                if ( !$QueueID && $currQueue ) {
                    
                    $Message = "QGR-Import: Creating QUEUE <$currQueue> ...";
                    if ( $Param{MessageToSTDERR} ) {
                        print STDERR "\n" . $Message;
                    }
                    else {
                        $LogObject->Log(
                            Priority => 'notice',
                            Message  => $Message,
                        );
                    }
                    
                    $QueueObject->QueueAdd(
                        Name    => $currQueue,
                        Comment => '',
                        GroupID => $GroupID,
                        %QueueAttributes,
                        UserID          => 1,
                        ValidID         => $ValidID,
                        SystemAddressID => $SystemAddressID,
                    );
                    
                    $QueueID = $QueueObject->QueueLookup( Queue => $currQueue );
                    $RevQueueList{$currQueue} = $QueueID;
                }
                else {

                    $Message = "QGR-Import: Updating QUEUE <$currQueue/ID: $QueueID> ...";
                    if ( $Param{MessageToSTDERR} ) {
                        print STDERR "\n" . $Message;
                    }
                    else {
                        $LogObject->Log(
                            Priority => 'notice',
                            Message  => $Message,
                        );
                    }

                    my %QueueData = $QueueObject->QueueGet(
                        ID => $QueueID,
                    );
                    $QueueObject->QueueUpdate(
                        QueueID => $QueueID,
                        %QueueAttributes,
                        Name => $currQueue || $QueueAttributes{Name} || $QueueData{Name},
                        GroupID => $GroupID || $QueueData{GroupID},
                        ValidID => $ValidID || $QueueAttributes{ValidID} || $QueueData{ValidID},
                        SystemAddressID => $SystemAddressID
                            || $QueueAttributes{SystemAddressID}
                            || $QueueData{SystemAddressID},
                        UserID => 1,
                    );
                }
            }

            #-----------------------------------------------------------------------
            # handle role rights...
            if ($GroupID) {
                my $currRoleIndex = 0;
                for my $currRoleRights (@currLine) {

                    $Message = "QGR-Import: Granting role <"
                        . $RoleNames[$currRoleIndex] . "/" . $RoleIDs[$currRoleIndex]
                        . "> permissions to group <"
                        . $currGroup . "/" . $GroupID
                        . ">: "
                        . ( $currRoleRights || '-' );
                    if ( $Param{MessageToSTDERR} ) {
                        print STDERR "\n" . $Message;
                    }
                    else {
                        $LogObject->Log(
                            Priority => 'notice',
                            Message  => $Message,
                        );
                    }

                    if ( $RoleIDs[$currRoleIndex] ) {
                        my %ShortcutMappings;
                        my %Permission = ();
                        if ( $QGRConfig
                             && ref($QGRConfig) eq 'HASH'
                             && $QGRConfig->{ShortcutMappings}
                             && ref($QGRConfig->{ShortcutMappings}) eq 'HASH'
                             && $QGRConfig->{ShortcutMappings}->{'rw'}
                        ) {
                            %ShortcutMappings = %{$QGRConfig->{ShortcutMappings}};
                            for my $SystemPermission (keys %ShortcutMappings) {
                                $Permission{$SystemPermission} = 
                                          $currRoleRights =~ /rw/ 
                                          || $currRoleRights =~ /$ShortcutMappings{$SystemPermission}/ 
                                          || $currRoleRights =~ /$SystemPermission/ 
                                          || 0; 
                            }
                        } 
                        else {
                            %Permission = (
                                ro => ( $currRoleRights =~ /RW/ )
                                    || ( $currRoleRights =~ /RO/ )
                                    || ( $currRoleRights =~ /ro/ )
                                    || 0,
                                move_into => ( $currRoleRights =~ /RW/ )
                                    || ( $currRoleRights =~ /MO/ )
                                    || ( $currRoleRights =~ /move_into/ )
                                    || 0,
                                create => ( $currRoleRights =~ /RW/ )
                                    || ( $currRoleRights =~ /CR/ )
                                    || ( $currRoleRights =~ /create/ )
                                    || 0,
                                owner => ( $currRoleRights =~ /RW/ )
                                    || ( $currRoleRights =~ /OW/ )
                                    || ( $currRoleRights =~ /owner/ )
                                    || 0,
                                note => ( $currRoleRights =~ /RW/ )
                                    || ( $currRoleRights =~ /NO/ )
                                    || ( $currRoleRights =~ /note/ )
                                    || 0,
                                priority => ( $currRoleRights =~ /RW/ )
                                    || ( $currRoleRights =~ /PR/ )
                                    || ( $currRoleRights =~ /priority/ )
                                    || 0,
                                rw => ( $currRoleRights =~ /RW/ )
                                    || ( $currRoleRights =~ /rw/ )
                                    || 0,
                            );
                        }
                        $GroupObject->GroupRoleMemberAdd(
                            RID        => $RoleIDs[$currRoleIndex],
                            GID        => $GroupID,
                            Permission => \%Permission,
                            UserID     => 1,
                        );
                    }
                    $currRoleIndex++;
                }
            }
        }
    }

    return 1;
}

sub Download {
    my ( $Self, %Param ) = @_;

    my @Head = $Param{Head};
    my @Data = $Param{Data};

    my $CSVResult = $Kernel::OM->Get('Kernel::System::CSV')->Array2CSV(
        Head      => @Head,
        Data      => @Data,
        Separator => ';',
        Quote     => '"',
    );

    return $CSVResult;
}

sub QGRShow {
    my ( $Self, %Param ) = @_;
    
    my $QGRConfig   = $Kernel::OM->Get('Kernel::Config')->Get("QueuesGroupsRoles");
    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    my %Groups = $GroupObject->GroupList( Valid => 1 );
    my %Queues = $QueueObject->QueueList( Valid => 0 );
    my @Data;
    my %UsedGroups;
    my @GroupData;
    my @RoleNames;

    my %ShortcutMappings;
    if ( $QGRConfig
         && ref($QGRConfig) eq 'HASH'
         && $QGRConfig->{ShortcutMappings}
         && ref($QGRConfig->{ShortcutMappings}) eq 'HASH'
         && $QGRConfig->{ShortcutMappings}->{'rw'}
    ) {
        %ShortcutMappings = %{$QGRConfig->{ShortcutMappings}};
    } 

    my @QueueParams = (
        'SalutationID',  'SignatureID',       'FollowUpID',          'FollowUpLock',
        'UnlockTimeout', 'FirstResponseTime', 'FirstResponseNotify', 'UpdateTime', 'UpdateNotify',
        'SolutionTime',  'SolutionNotify',    'Calendar',            'ValidID', 'SystemAddress'
    );

    my @QueueParamsOutput = (
        'SalutationID',  'SignatureID',       'FollowUpID',          'FollowUpLock',
        'UnlockTimeout', 'FirstResponseTime', 'FirstResponseNotify', 'UpdateTime', 'UpdateNotify',
        'SolutionTime',  'SolutionNotify',    'Calendar',            'Validity', 'SystemAddress'
    );

    my %Roles = $GroupObject->RoleList( Valid => 1 );
    for my $Role ( keys(%Roles) ) {
        push( @RoleNames, $Roles{$Role} );
    }

    my $Permission = $Kernel::OM->Get('Kernel::Config')->Get('System::Permission');

    for my $QueueID ( keys(%Queues) ) {
        my @Line = ();
        push( @Line, $Queues{$QueueID} );

        my $GroupID = $QueueObject->GetQueueGroupID( QueueID => $QueueID );
        my $Group = $GroupObject->GroupLookup( GroupID => $GroupID );
        push( @Line, $Group );
        $UsedGroups{$Group} = 1;

        my %Queue = $QueueObject->QueueGet(
            ID => $QueueID,
        );
        
        # prepare SystemAddress...
        my %SystemAddress = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressGet(
            ID => $Queue{SystemAddressID},
        );
        $Queue{SystemAddress} = '"'.$SystemAddress{Realname}.'" <'.$SystemAddress{Name}.'>';

        for my $QueueParam (@QueueParams) {
            if ( $QueueParam eq 'ValidID' ) {
                my $Valid = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
                    ValidID => $Queue{$QueueParam},
                );
                $Queue{$QueueParam} = $Valid;
            }
            push( @Line, $Queue{$QueueParam} || 0 );
        }

        my %RolePermissions;

        for my $Type ( @{$Permission} ) {

            my %GroupRoles = $GroupObject->GroupRoleMemberList(
                GroupID => $GroupID,
                Type    => $Type,
                Result  => 'HASH',
            );

            for my $RoleID ( keys(%GroupRoles) ) {

                my $Role = $GroupObject->RoleLookup( RoleID => $RoleID );
                if (%ShortcutMappings && $ShortcutMappings{$Type}) {
                    $RolePermissions{$Role} .= $ShortcutMappings{$Type} . ",";
                }
                else {
                    $RolePermissions{$Role} .= $Type . ",";
                }
            }
        }

        for my $RoleNames (@RoleNames) {
            if ( $RolePermissions{$RoleNames} ) {
                push( @Line, $RolePermissions{$RoleNames} );
            }
            else {
                push( @Line, '' );
            }
        }
        push( @Data, \@Line );
    }

    @Data = sort { "\U$a->[0]" cmp "\U$b->[0]" } @Data;

    for my $GroupID ( keys(%Groups) ) {
        next if $UsedGroups{ $Groups{$GroupID} };

        my @Line = ();
        push( @Line, "" );
        push( @Line, $Groups{$GroupID} );

        for my $QueueParam (@QueueParams) {
            push( @Line, "" );
        }

        my %RolePermissions;

        for my $Type ( @{$Permission} ) {

            my %GroupRoles = $GroupObject->GroupRoleMemberList(
                GroupID => $GroupID,
                Type    => $Type,
                Result  => 'HASH',
            );

            for my $RoleID ( keys(%GroupRoles) ) {

                my $Role = $GroupObject->RoleLookup( RoleID => $RoleID );
                if (%ShortcutMappings && $ShortcutMappings{$Type}) {
                    $RolePermissions{$Role} .= $ShortcutMappings{$Type} . ",";
                }
                else {
                    $RolePermissions{$Role} .= $Type . ",";
                }
            }
        }

        for my $RoleNames (@RoleNames) {
            if ( $RolePermissions{$RoleNames} ) {
                push( @Line, $RolePermissions{$RoleNames} );
            }
            else {
                push( @Line, '' );
            }
        }

        push( @GroupData, \@Line );
    }

    @GroupData = sort { "\U$a->[1]" cmp "\U$b->[1]" } @GroupData;
    for my $Line (@GroupData) {
        push( @Data, $Line );
    }

    my @Head = ( 'Queue', 'Gruppe', @QueueParamsOutput, @RoleNames );

    return ( \@Head, \@Data );
}

1;
