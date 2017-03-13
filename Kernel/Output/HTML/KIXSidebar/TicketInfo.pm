# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::KIXSidebar::TicketInfo;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    $Self->{DynamicFieldFilter}
        = $ConfigObject->Get("Ticket::Frontend::AgentTicketZoom")->{DynamicField};

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $TimeObject         = $Kernel::OM->Get('Kernel::System::Time');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Content;

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 1
    );
    my %CustomerData    = %{ $Param{CustomerData} };
    my %ResponsibleInfo = %{ $Param{ResponsibleInfo} };
    my %AclAction       = %{ $Param{AclAction} };

    # check if ticket is normal or process ticket
    my $IsProcessTicket = $TicketObject->TicketCheckForProcessType(
        'TicketID' => $Self->{TicketID}
    );

    # get direct ticket data...
    $LayoutObject->Block(
        Name => 'TicketDirectData',
        Data => { %CustomerData, %ResponsibleInfo, %Ticket },
    );

    # show process widget  and activity dialogs on process tickets
    if ($IsProcessTicket) {

        my $ActivityObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::Activity');
        my $ProcessObject  = $Kernel::OM->Get('Kernel::System::ProcessManagement::Process');

        # get the DF where the ProcessEntityID is stored
        my $ProcessEntityIDField = 'DynamicField_'
            . $ConfigObject->Get("Process::DynamicFieldProcessManagementProcessID");

        # get the DF where the AtivityEntityID is stored
        my $ActivityEntityIDField = 'DynamicField_'
            . $ConfigObject->Get("Process::DynamicFieldProcessManagementActivityID");

        my $ProcessData = $ProcessObject->ProcessGet(
            ProcessEntityID => $Ticket{$ProcessEntityIDField},
        );
        my $ActivityData = $ActivityObject->ActivityGet(
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
    }

    # get the dynamic fields for ticket object
    my $DynamicField = $DynamicFieldObject->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Ticket'],
        FieldFilter => $Self->{DynamicFieldFilter} || {},
    );

    # cycle trough the activated Dynamic Fields for ticket object
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if !defined $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} };
        next DYNAMICFIELD if $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} } eq '';

        # get print string for this dynamic field
        my $ValueStrg = $BackendObject->DisplayValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
            ValueMaxChars =>
                $ConfigObject->Get("Ticket::Frontend::AgentTicketZoom")->{TicketDataLength}
                || '',
            LayoutObject => $LayoutObject,
        );

        $LayoutObject->Block(
            Name => 'DynamicFieldContent',
            Data => {
                Label => $DynamicFieldConfig->{Label},
            },
        );

        if ( $DynamicFieldConfig->{FieldType} eq 'DateTime' ) {
            $LayoutObject->Block(
                Name => 'DynamicFieldContentTime',
                Data => {
                    Value => $ValueStrg->{Value},
                    Title => $ValueStrg->{Title},
                },
            );
        }
        elsif (
            $DynamicFieldConfig->{FieldType}    eq 'Dropdown'
            || $DynamicFieldConfig->{FieldType} eq 'Multiselect'
            || $DynamicFieldConfig->{FieldType} eq 'MultiselectGeneralCatalog'
            || $DynamicFieldConfig->{FieldType} eq 'DropdownGeneralCatalog'
            )
        {
            $LayoutObject->Block(
                Name => 'DynamicFieldContentQuoted',
                Data => {
                    Value => $ValueStrg->{Value},
                    Title => $ValueStrg->{Title},
                },
            );
        }
        elsif ( $DynamicFieldConfig->{FieldType} eq 'Checkbox' ) {
            my $Checked = '';
            if ( $ValueStrg->{Value} eq $LayoutObject->{LanguageObject}->Translate('Checked') ) {
                $Checked = 'Checked="Checked"';
            }
            $LayoutObject->Block(
                Name => 'DynamicFieldContentCheckbox',
                Data => {
                    Value => $Checked,
                    Title => $ValueStrg->{Title},
                },
            );
        }
        elsif ( $ValueStrg->{Link} ) {
            $LayoutObject->Block(
                Name => 'DynamicFieldContentLink',
                Data => {
                    %Ticket,
                    Value                       => $ValueStrg->{Value},
                    Title                       => $ValueStrg->{Title},
                    Link                        => $ValueStrg->{Link},
                    $DynamicFieldConfig->{Name} => $ValueStrg->{Title},
                },
            );
        }
        else {
            $LayoutObject->Block(
                Name => 'DynamicFieldContentRaw',
                Data => {
                    Value => $ValueStrg->{Value},
                    Title => $ValueStrg->{Title},
                },
            );
        }

        # example of dynamic fields order customization
        $LayoutObject->Block(
            Name => 'TicketDynamicField_' . $DynamicFieldConfig->{Name},
            Data => {
                Label => $DynamicFieldConfig->{Label},
            },
        );

    }

    my $DirectDataConfRef = $Param{ModuleConfig}->{'TicketDataKeys'};
    for my $TicketKey ( sort( keys( %{$DirectDataConfRef} ) ) ) {

        # check if this value is a CallMethod
        if (
            !$Ticket{ $DirectDataConfRef->{$TicketKey} }
            && $Self->_IsCallMethod( $DirectDataConfRef->{$TicketKey} )
            )
        {
            $Ticket{ $DirectDataConfRef->{$TicketKey} } =
                $Self->_ExecCallMethod(
                $DirectDataConfRef->{$TicketKey},
                %{$Self}, %CustomerData, %ResponsibleInfo, %Ticket
                );
        }

        next if ( !$Ticket{ $DirectDataConfRef->{$TicketKey} } );

        my $Label       = $DirectDataConfRef->{$TicketKey};
        my $ShortRef    = $DirectDataConfRef->{$TicketKey};
        my $ContentLink = "";

        if ( $Label =~ /^(DynamicField_)(.*)/ ) {
            $Label = $2;
        }
        elsif ( $Param{ModuleConfig}->{TicketDataLabel}->{$Label} ) {
            $Label = $Param{ModuleConfig}->{TicketDataLabel}->{$Label};

            # check if we have some callmethod as label definition
            if ( $Self->_IsCallMethod($Label) ) {
                $Label = $Self->_ExecCallMethod(
                    $Label, %{$Self}, %Ticket, %CustomerData, %ResponsibleInfo,
                );
            }
        }

        $LayoutObject->Block(
            Name => 'KeyContent',
            Data => { Label => $Label, },
        );

        if ( $TicketKey =~ /\d+Translated$/ ) {
            $LayoutObject->Block(
                Name => 'KeyContentTranslated',
                Data => {
                    Content => $Ticket{$ShortRef},
                },
            );
        }
        elsif ( $TicketKey =~ /\d+Unquoted$/ ) {
            $LayoutObject->Block(
                Name => 'KeyContentUnquoted',
                Data => {
                    Content => $Ticket{$ShortRef},
                },
            );
        }
        elsif ( $TicketKey =~ /\d+UnquotedNewLinedBy(.+)$/ ) {
            my $Separator = $1;
            my $Content   = $Ticket{$ShortRef};
            $Content =~ s/$Separator/<br \/>$Separator/g;
            $LayoutObject->Block(
                Name => 'KeyContentUnquoted',
                Data => {
                    Content => $Content,
                },
            );

        }
        elsif ($ContentLink) {

            # needed for SystemMonitoringX
            $ContentLink = $LayoutObject->Output(
                Template => $ContentLink,
                Data     => {
                    %Ticket,
                },
            );

            $LayoutObject->Block(
                Name => 'KeyContentLinked',
                Data => {
                    Content     => $Ticket{$ShortRef},
                    ContentLink => $ContentLink,
                    $ShortRef   => $Ticket{$ShortRef},
                },
            );
        }
        elsif ( $TicketKey =~ /\d+TimeLong$/ ) {
            $LayoutObject->Block(
                Name => 'KeyContentTimeLong',
                Data => {
                    Content => $Ticket{$ShortRef},
                },
            );
        }
        elsif ( $TicketKey =~ /\d+TimeShort$/ ) {
            $LayoutObject->Block(
                Name => 'KeyContentTimeShort',
                Data => {
                    Content => $Ticket{$ShortRef},
                },
            );
        }
        else {

            my $ValueHashRef = $ConfigObject->Get($ShortRef);
            if (
                $ValueHashRef
                && ref($ValueHashRef) eq 'HASH'
                && $ValueHashRef->{ $Ticket{$ShortRef} }
                )
            {
                $Ticket{$ShortRef} = $ValueHashRef->{ $Ticket{$ShortRef} };
            }

            $LayoutObject->Block(
                Name => 'KeyContentQuoted',
                Data => {
                    Content => $Ticket{$ShortRef},
                },
            );
        }

    }

    # show first response time if needed
    if ( defined $Ticket{FirstResponseTime} ) {
        $Ticket{FirstResponseTimeHuman} = $LayoutObject->CustomerAgeInHours(
            Age   => $Ticket{FirstResponseTime},
            Space => ' ',
        );
        $Ticket{FirstResponseTimeWorkingTime} = $LayoutObject->CustomerAgeInHours(
            Age   => $Ticket{FirstResponseTimeWorkingTime},
            Space => ' ',
        );
        if ( 60 * 60 * 1 > $Ticket{FirstResponseTime} ) {
            $Ticket{FirstResponseTimeClass} = 'Warning';
        }
        $LayoutObject->Block(
            Name => 'FirstResponseTime',
            Data => { %Ticket, %AclAction },
        );
    }

    # show update time if needed
    if ( defined $Ticket{UpdateTime} ) {
        $Ticket{UpdateTimeHuman} = $LayoutObject->CustomerAgeInHours(
            Age   => $Ticket{UpdateTime},
            Space => ' ',
        );
        $Ticket{UpdateTimeWorkingTime} =
            $LayoutObject->CustomerAgeInHours(
            Age   => $Ticket{UpdateTimeWorkingTime},
            Space => ' ',
            );
        if ( 60 * 60 * 1 > $Ticket{UpdateTime} ) {
            $Ticket{UpdateTimeClass} = 'Warning';
        }
        $LayoutObject->Block(
            Name => 'UpdateTime',
            Data => { %Ticket, %AclAction },
        );
    }

    # show solution time if needed
    if ( defined $Ticket{SolutionTime} ) {
        if ( $Ticket{SolutionTimeDestinationDate} =~ m/[31.12.2025|12.31.2025|2025.12.31] 01:00/ ) {
            $LayoutObject->Block(
                Name => 'SolutionTimeSuspended',
                Data => { %Param, %Ticket },
            );
        }
        else {
            $Ticket{SolutionTimeHuman} = $LayoutObject->CustomerAgeInHours(
                Age   => $Ticket{SolutionTime},
                Space => ' ',
            );
            $Ticket{SolutionTimeWorkingTime} =
                $LayoutObject->CustomerAgeInHours(
                Age   => $Ticket{SolutionTimeWorkingTime},
                Space => ' ',
                );
            if ( 60 * 60 * 1 > $Ticket{SolutionTime} ) {
                $Ticket{SolutionTimeClass} = 'Warning';
            }
            $LayoutObject->Block(
                Name => 'SolutionTime',
                Data => { %Ticket, %AclAction },
            );
        }
    }

    # show pending until, if set:
    if ( $Ticket{UntilTime} ) {
        if ( $Ticket{UntilTime} < -1 ) {
            $Ticket{PendingUntilClass} = 'Warning';
        }

        my %UserPreferences = $UserObject->GetPreferences( UserID => $Self->{UserID} );
        my $DisplayPendingTime = $UserPreferences{UserDisplayPendingTime} || '';

        if ( $DisplayPendingTime && $DisplayPendingTime eq 'RemainingTime' ) {
            $Ticket{PendingUntil} .= $LayoutObject->CustomerAge(
                Age   => $Ticket{UntilTime},
                Space => '<br/>'
            );
        }
        else {
            $Ticket{PendingUntil} = $TimeObject->SystemTime2TimeStamp(
                SystemTime => $Ticket{RealTillTimeNotUsed},
            );
            $Ticket{PendingUntil} = $LayoutObject->{LanguageObject}
                ->FormatTimeString( $Ticket{PendingUntil}, 'DateFormat' );
        }
        $LayoutObject->Block(
            Name => 'PendingUntil',
            Data => \%Ticket,
        );
    }

    # output result
    $Content = $LayoutObject->Output(
        TemplateFile => 'AgentKIXSidebarTicketInfo',
        Data         => {
            %Param,
            %{ $Self->{Config} },
        },
        KeepScriptTags => $Param{AJAX},
    );

    return $Content;
}

sub _IsCallMethod {
    my ( $Self, $Value ) = @_;

    return ( $Value =~ /CallMethod::(\w+)::(\w+)::(\w+)/ || $Value =~ /CallMethod::(\w+)::(\w+)/ );
}

sub _ExecCallMethod {
    my ( $Self, $Value, %Param ) = @_;
    my $Result;

    if ( $Value =~ /CallMethod::(\w+)Object::(\w+)::(\w+)/ || $Value =~ /CallMethod::(\w+)Object::(\w+)/ ) {
        my $ObjectType = $1;
        my $Method     = $2;
        my $Hashresult = $3;

        my $DisplayResult;
        my $Object;
        if ( $Hashresult && $Hashresult ne '' ) {
            eval {
                $Object =  $Kernel::OM->Get('Kernel::System::'.$ObjectType);
                $DisplayResult = { $Object->$Method(%Param) }->{$Hashresult};
            };
        }
        else {
            eval {
                $Object =  $Kernel::OM->Get('Kernel::System::'.$ObjectType);
                $DisplayResult = $Object->$Method(%Param);
            };
        }

        if ($DisplayResult) {
            $Result = $DisplayResult;
        }
        if ($@) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "KIXSidebarTicketInfo - "
                    . " invalid CallMethod ($Object->$Method) configured "
                    . "(" . $@ . ")!",
            );
        }
    }

    return $Result;
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
