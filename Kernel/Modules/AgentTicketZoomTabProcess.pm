# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketZoomTabProcess;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use POSIX qw/ceil/;

use Kernel::Language qw(Translatable);
use Kernel::System::EmailParser;
use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # set debug
    $Self->{Debug} = 0;

    # get needed objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    $Self->{ArticleID}      = $ParamObject->GetParam( Param => 'ArticleID' );
    $Self->{ZoomExpand}     = $ParamObject->GetParam( Param => 'ZoomExpand' );
    $Self->{ZoomExpandSort} = $ParamObject->GetParam( Param => 'ZoomExpandSort' );

    $Self->{CallingAction}    = $ParamObject->GetParam( Param => 'CallingAction' )    || '';
    $Self->{DirectLinkAnchor} = $ParamObject->GetParam( Param => 'DirectLinkAnchor' ) || '';
    $Self->{Config} = $ConfigObject->Get('Ticket::Frontend::AgentTicketZoomTabProcess');

    # ticket id lookup
    if ( !$Self->{TicketID} && $ParamObject->GetParam( Param => 'TicketNumber' ) ) {
        $Self->{TicketID} = $TicketObject->TicketIDLookup(
            TicketNumber => $ParamObject->GetParam( Param => 'TicketNumber' ),
            UserID       => $Self->{UserID},
        );
    }

    # get zoom settings depending on ticket type
    $Self->{DisplaySettings} = $ConfigObject->Get("Ticket::Frontend::AgentTicketZoom");

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check needed stuff
    if ( !$Self->{TicketID} ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('No TicketID is given!'),
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => 'ro',
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID}
    );

    # error screen, don't show ticket
    return $LayoutObject->NoPermission(
        Message => Translatable(
            'We are sorry, you do not have permissions anymore to access this ticket in its current state.'
        ),
        WithHeader => 'yes',
    ) if !$Access;

    # get ticket attributes
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Self->{TicketID},
        DynamicFields => 1,
    );

    # get ACL restrictions
    my %PossibleActions;
    my $Counter = 0;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $ImagePath = $ConfigObject->Get('Frontend::ImagePath');

    # get all registered Actions
    if ( ref $ConfigObject->Get('Frontend::Module') eq 'HASH' ) {

        my %Actions = %{ $ConfigObject->Get('Frontend::Module') };

        # only use those Actions that stats with Agent
        %PossibleActions = map { ++$Counter => $_ }
            grep { substr( $_, 0, length 'Agent' ) eq 'Agent' }
            sort keys %Actions;
    }

    my $ACL = $TicketObject->TicketAcl(
        Data          => \%PossibleActions,
        Action        => $Self->{Action},
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );

    my %AclAction = %PossibleActions;
    if ($ACL) {
        %AclAction = $TicketObject->TicketAclActionData();
    }

    # check if ACL restrictions exist
    my %AclActionLookup = reverse %AclAction;

    # show error screen if ACL prohibits this action
    if ( !$AclActionLookup{ $Self->{Action} } ) {
        return $LayoutObject->NoPermission( WithHeader => 'yes' );
    }

    my $Output = $Self->MaskAgentZoom(
        Ticket    => \%Ticket,
        AclAction => \%AclAction
    );

    $Output .= $LayoutObject->Footer( Type => 'TicketZoomTab' );

    return $Output;
}

sub MaskAgentZoom {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Ticket    = %{ $Param{Ticket} };
    my %AclAction = %{ $Param{AclAction} };

    # set display options
    $Param{WidgetTitle} = 'Ticket Information';
    $Param{Hook}        = $ConfigObject->Get('Ticket::Hook') || 'Ticket#';

    # check if ticket is normal or process ticket
    my $IsProcessTicket = $TicketObject->TicketCheckForProcessType(
        'TicketID' => $Self->{TicketID}
    );

    # overwrite display options for process ticket
    if ($IsProcessTicket) {
        $Param{WidgetTitle} = $Self->{DisplaySettings}->{ProcessDisplay}->{WidgetTitle};
    }

    $LayoutObject->Block(
        Name => 'Header',
        Data => { %Param, %Ticket, %AclAction },
    );

    # show process widget  and activity dialogs on process tickets
    if ($IsProcessTicket) {

        # get the DF where the ProcessEntityID is stored
        my $ProcessEntityIDField = 'DynamicField_'
            . $ConfigObject->Get("Process::DynamicFieldProcessManagementProcessID");

        # get the DF where the AtivityEntityID is stored
        my $ActivityEntityIDField = 'DynamicField_'
            . $ConfigObject->Get("Process::DynamicFieldProcessManagementActivityID");

        my $ProcessData
            = $Kernel::OM->Get('Kernel::System::ProcessManagement::Process')->ProcessGet(
            ProcessEntityID => $Ticket{$ProcessEntityIDField},
            );
        my $ActivityData
            = $Kernel::OM->Get('Kernel::System::ProcessManagement::Activity')->ActivityGet(
            Interface        => 'AgentInterface',
            ActivityEntityID => $Ticket{$ActivityEntityIDField},
            );

        # output process information in the sidebar
        $LayoutObject->Block(
            Name => 'ProcessData',
            Data => {
                Process  => $ProcessData->{Name}  || '',
                Activity => $ActivityData->{Name} || '',
            },
        );

        # output the process widget the the main screen
        $LayoutObject->Block(
            Name => 'ProcessWidget',
            Data => {
                WidgetTitle => $Param{WidgetTitle},
            },
        );

        # get next activity dialogs
        my $NextActivityDialogs;
        if ( $Ticket{$ActivityEntityIDField} ) {
            $NextActivityDialogs = ${ActivityData}->{ActivityDialog} // {};
        }
        my $ActivityName = $ActivityData->{Name};

        if ($NextActivityDialogs) {

            # get ActivityDialog object
            my $ActivityDialogObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::ActivityDialog');

            # we have to check if the current user has the needed permissions to view the
            # different activity dialogs, so we loop over every activity dialog and check if there
            # is a permission configured. If there is a permission configured we check this
            # and display/hide the activity dialog link
            my %PermissionRights;
            my %PermissionActivityDialogList;
            ACTIVITYDIALOGPERMISSION:
            for my $Index ( sort { $a <=> $b } keys %{$NextActivityDialogs} ) {
                my $CurrentActivityDialogEntityID = $NextActivityDialogs->{$Index};
                my $CurrentActivityDialog         = $ActivityDialogObject->ActivityDialogGet(
                    Interface              => 'AgentInterface',
                    ActivityDialogEntityID => $CurrentActivityDialogEntityID
                );

                # create an interface lookup-list
                my %InterfaceLookup = map { $_ => 1 } @{ $CurrentActivityDialog->{Interface} };

                next ACTIVITYDIALOGPERMISSION if !$InterfaceLookup{AgentInterface};

                if ( $CurrentActivityDialog->{Permission} ) {

                    # performance-boost/cache
                    if ( !defined $PermissionRights{ $CurrentActivityDialog->{Permission} } ) {
                        $PermissionRights{ $CurrentActivityDialog->{Permission} } = $TicketObject->TicketPermission(
                            Type     => $CurrentActivityDialog->{Permission},
                            TicketID => $Ticket{TicketID},
                            UserID   => $Self->{UserID},
                        );
                    }

                    if ( !$PermissionRights{ $CurrentActivityDialog->{Permission} } ) {
                        next ACTIVITYDIALOGPERMISSION;
                    }
                }

                $PermissionActivityDialogList{$Index} = $CurrentActivityDialogEntityID;
            }

            # reduce next activity dialogs to the ones that have permissions
            $NextActivityDialogs = \%PermissionActivityDialogList;

            # get ACL restrictions
            my $ACL = $TicketObject->TicketAcl(
                Data          => \%PermissionActivityDialogList,
                TicketID      => $Ticket{TicketID},
                ReturnType    => 'ActivityDialog',
                ReturnSubType => '-',
                UserID        => $Self->{UserID},
            );

            if ($ACL) {
                %{$NextActivityDialogs} = $TicketObject->TicketAclData()
            }

            $LayoutObject->Block(
                Name => 'NextActivityDialogs',
                Data => {
                    'ActivityName' => $ActivityName,
                },
            );

            if ( IsHashRefWithData($NextActivityDialogs) ) {
                for my $NextActivityDialogKey ( sort { $a <=> $b } keys %{$NextActivityDialogs} ) {
                    my $ActivityDialogData = $ActivityDialogObject->ActivityDialogGet(
                        Interface              => 'AgentInterface',
                        ActivityDialogEntityID => $NextActivityDialogs->{$NextActivityDialogKey},
                    );
                    $LayoutObject->Block(
                        Name => 'ActivityDialog',
                        Data => {
                            ActivityDialogEntityID
                                => $NextActivityDialogs->{$NextActivityDialogKey},
                            Name            => $ActivityDialogData->{Name},
                            ProcessEntityID => $Ticket{$ProcessEntityIDField},
                            TicketID        => $Ticket{TicketID},
                        },
                    );
                }
            }
            else {
                $LayoutObject->Block(
                    Name => 'NoActivityDialogs',
                    Data => {},
                );
            }
        }
    }

    # get dynamic field config for frontend module
    my $DynamicFieldFilter = {
        %{ $ConfigObject->Get("Ticket::Frontend::AgentTicketZoom")->{DynamicField} || {} },
        %{
            $ConfigObject->Get("Ticket::Frontend::AgentTicketZoom")
                ->{ProcessWidgetDynamicField}
                || {}
        },
    };

    # get the dynamic fields for ticket object
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Ticket'],
        FieldFilter => $DynamicFieldFilter || {},
    );
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # to store dynamic fields to be displayed in the process widget and in the sidebar
    my ( @FieldsWidget, @FieldsSidebar );

    # cycle trough the activated Dynamic Fields for ticket object
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if !defined $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} };
        next DYNAMICFIELD if $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} } eq '';

        # use translation here to be able to reduce the character length in the template
        my $Label = $LayoutObject->{LanguageObject}->Translate( $DynamicFieldConfig->{Label} );

        if (
            $IsProcessTicket &&
            $Self->{DisplaySettings}->{ProcessWidgetDynamicField}->{ $DynamicFieldConfig->{Name} }
        ) {
            my $ValueStrg = $DynamicFieldBackendObject->DisplayValueRender(
                DynamicFieldConfig => $DynamicFieldConfig,
                Value              => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                LayoutObject       => $LayoutObject,
                HTMLOutput         => 1,
                # no ValueMaxChars here, enough space available
            );

            push @FieldsWidget, {
                Name  => $DynamicFieldConfig->{Name},
                Title => $ValueStrg->{Title},
                Value => $ValueStrg->{Value},
                ValueKey
                    => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                Label                       => $Label,
                Link                        => $ValueStrg->{Link},
                LinkPreview                 => $ValueStrg->{LinkPreview},
                $DynamicFieldConfig->{Name} => $ValueStrg->{Title},
            };
        }

        my $ValueStrg = $DynamicFieldBackendObject->DisplayValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
            LayoutObject       => $LayoutObject,
            ValueMaxChars      => $ConfigObject->
                Get('Ticket::Frontend::DynamicFieldsZoomMaxSizeSidebar')
                || 18,    # limit for sidebar display
        );

        if (
            $Self->{DisplaySettings}->{DynamicField}->{ $DynamicFieldConfig->{Name} }
        ) {
            push @FieldsSidebar, {
                Name                        => $DynamicFieldConfig->{Name},
                Title                       => $ValueStrg->{Title},
                Value                       => $ValueStrg->{Value},
                Label                       => $Label,
                Link                        => $ValueStrg->{Link},
                LinkPreview                 => $ValueStrg->{LinkPreview},
                $DynamicFieldConfig->{Name} => $ValueStrg->{Title},
            };
        }

        # example of dynamic fields order customization
        $LayoutObject->Block(
            Name => 'TicketDynamicField_' . $DynamicFieldConfig->{Name},
            Data => {
                Label => $Label,
            },
        );

        $LayoutObject->Block(
            Name => 'TicketDynamicField_' . $DynamicFieldConfig->{Name} . '_Plain',
            Data => {
                Value => $ValueStrg->{Value},
                Title => $ValueStrg->{Title},
            },
        );
    }

    if ($IsProcessTicket) {

        # output dynamic fields registered for a group in the process widget
        my @FieldsInAGroup;
        for my $GroupName (
            sort keys %{ $Self->{DisplaySettings}->{ProcessWidgetDynamicFieldGroups} }
        ) {

            $LayoutObject->Block(
                Name => 'ProcessWidgetDynamicFieldGroups',
            );

            my $GroupFieldsString = $Self->{DisplaySettings}->{ProcessWidgetDynamicFieldGroups}->{$GroupName};

            $GroupFieldsString =~ s{\s}{}xmsg;
            my @GroupFields = split( ',', $GroupFieldsString );

            if ( $#GroupFields + 1 ) {

                my $ShowGroupTitle = 0;
                for my $Field (@FieldsWidget) {

                    if ( grep { $_ eq $Field->{Name} } @GroupFields ) {

                        $ShowGroupTitle = 1;
                        $LayoutObject->Block(
                            Name => 'ProcessWidgetDynamicField',
                            Data => {
                                Label => $Field->{Label},
                                Name  => $Field->{Name},
                            },
                        );

                        $LayoutObject->Block(
                            Name => 'ProcessWidgetDynamicFieldValueOverlayTrigger',
                        );

                        if ( $Field->{Link} ) {
                            $LayoutObject->Block(
                                Name => 'ProcessWidgetDynamicFieldLink',
                                Data => {
                                    %Ticket,

                                    # alias for ticket title, Title will be overwritten
                                    TicketTitle    => $Ticket{Title},
                                    Value          => $Field->{Value},
                                    Title          => $Field->{Title},
                                    Link           => $Field->{Link},
                                    LinkPreview    => $Field->{LinkPreview},
                                    $Field->{Name} => $Field->{Title},
                                },
                            );
                        }
                        else {
                            $LayoutObject->Block(
                                Name => 'ProcessWidgetDynamicFieldPlain',
                                Data => {
                                    Value => $Field->{Value},
                                    Title => $Field->{Title},
                                },
                            );
                        }
                        push @FieldsInAGroup, $Field->{Name};
                    }
                }

                if ($ShowGroupTitle) {
                    $LayoutObject->Block(
                        Name => 'ProcessWidgetDynamicFieldGroupSeparator',
                        Data => {
                            Name => $GroupName,
                        },
                    );
                }
            }
        }

        # output dynamic fields not registered in a group in the process widget
        my @RemainingFieldsWidget;
        for my $Field (@FieldsWidget) {

            if ( !grep { $_ eq $Field->{Name} } @FieldsInAGroup ) {
                push @RemainingFieldsWidget, $Field;
            }
        }

        $LayoutObject->Block(
            Name => 'ProcessWidgetDynamicFieldGroups',
        );

        if ( $#RemainingFieldsWidget + 1 ) {

            $LayoutObject->Block(
                Name => 'ProcessWidgetDynamicFieldGroupSeparator',
                Data => {
                    Name =>
                        $LayoutObject->{LanguageObject}->Translate('Fields with no group'),
                },
            );
        }
        for my $Field (@RemainingFieldsWidget) {

            $LayoutObject->Block(
                Name => 'ProcessWidgetDynamicField',
                Data => {
                    Label => $Field->{Label},
                    Name  => $Field->{Name},
                },
            );

            $LayoutObject->Block(
                Name => 'ProcessWidgetDynamicFieldValueOverlayTrigger',
            );

            if ( $Field->{Link} ) {
                $LayoutObject->Block(
                    Name => 'ProcessWidgetDynamicFieldLink',
                    Data => {
                        %Ticket,

                        # alias for ticket title, Title will be overwritten
                        TicketTitle    => $Ticket{Title},
                        Value          => $Field->{Value},
                        Title          => $Field->{Title},
                        Link           => $Field->{Link},
                        LinkPreview    => $Field->{LinkPreview},
                        $Field->{Name} => $Field->{Title},
                    },
                );
            }
            else {
                $LayoutObject->Block(
                    Name => 'ProcessWidgetDynamicFieldPlain',
                    Data => {
                        Value => $Field->{Value},
                        Title => $Field->{Title},
                    },
                );
            }
        }
    }

    # return output
    return $LayoutObject->Output(
        TemplateFile => 'AgentTicketZoomTabProcess',
        Data         => {
            %Param,
            %Ticket,
            %AclAction
        },
    );
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
