# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::BaseTicketTemplateHandler;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

sub TicketTemplateReplace {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject                = $Kernel::OM->Get('Kernel::Config');
    my $DynamicFieldObject          = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $LayoutObject                = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $LogObject                   = $Kernel::OM->Get('Kernel::System::Log');
    my $ParamObject                 = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $PriorityObject              = $Kernel::OM->Get('Kernel::System::Priority');
    my $QueueObject                 = $Kernel::OM->Get('Kernel::System::Queue');
    my $StateObject                 = $Kernel::OM->Get('Kernel::System::State');
    my $TemplateGeneratorObject     = $Kernel::OM->Get('Kernel::System::TemplateGenerator');
    my $TicketObject                = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject                  = $Kernel::OM->Get('Kernel::System::User');

    # check needed stuff
    for my $Needed (qw(IsUpload Data DefaultSet)) {
        if ( !defined $Param{$Needed} ) {
            $LogObject
                ->Log( Priority => 'error', Message => "BaseTicketTemplateHandler: Need $Needed!" );
            return;
        }
    }

    if ( ref $Param{Data} ne 'HASH' ) {
        $LogObject
            ->Log(
            Priority => 'error',
            Message  => "TicketTemplateUpdate: Given data needs to be a hash element!"
            );
        return;
    }
    my %Data = %{ $Param{Data} };
    my @MultipleCustomer;
    my @MultipleCustomerCc;
    my @MultipleCustomerBcc;

    if ( $Self->{Action} =~ m/^AgentTicket.*$/ ) {
        @MultipleCustomer = @{ $Param{MultipleCustomer} };
        if ( $Self->{Action} eq 'AgentTicketEmail' ) {
            @MultipleCustomerCc  = @{ $Param{MultipleCustomerCc} };
            @MultipleCustomerBcc = @{ $Param{MultipleCustomerBcc} };
        }
    }

    # If is an action about attachments
    my $IsUpload = $Param{IsUpload};

    my %TicketTemplate = $TicketObject->TicketTemplateGet(
        ID => $Param{DefaultSet},
    );

    if ( !%TicketTemplate || ref \%TicketTemplate ne 'HASH' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Default set used, but not defined!",
        );
    }
    else {

        my %Ticket;
        if ( $Self->{TicketID} ) {
            %Ticket = $TicketObject->TicketGet( TicketID => $Self->{TicketID} );
        }

        # check if there are actions about attachments
        my @AttachmentIDs = ();
        for my $Name ( $ParamObject->GetParamNames() ) {
            if ( $Name =~ m{ \A AttachmentDelete (\d+) \z }xms ) {
                push (@AttachmentIDs, $1);
            };
        }

        for my $Count ( reverse sort @AttachmentIDs ) {
            my $Delete
                = $ParamObject->GetParam( Param => "AttachmentDelete$Count" );
            next if !$Delete;
            $IsUpload = 1;
        }

        if ( $ParamObject->GetParam( Param => 'AttachmentUpload' ) ) {
            $IsUpload = 1;
        }

        # set default value for customer login
        if ( $Self->{Action} ne 'CustomerTicketMessage' ) {
            for my $Key (qw(From Cc Bcc)) {

                my $ExtKey = '';
                $ExtKey = $Key if $Key ne 'From';

                # get current customer array
                my @TempArray;
                @TempArray = @{ $Param{MultipleCustomer} }    if $Key eq 'From';
                @TempArray = @{ $Param{MultipleCustomerCc} }  if $Key eq 'Cc';
                @TempArray = @{ $Param{MultipleCustomerBcc} } if $Key eq 'Bcc';

                # get size of customer array
                my $TempArrayCount;
                $TempArrayCount = scalar @{ $Param{MultipleCustomer} }    if $Key eq 'From';
                $TempArrayCount = scalar @{ $Param{MultipleCustomerCc} }  if $Key eq 'Cc';
                $TempArrayCount = scalar @{ $Param{MultipleCustomerBcc} } if $Key eq 'Bcc';

                if ( $TicketTemplate{$Key} ) {

                    $TicketTemplate{$Key} =~ s/OTRS_/KIX_/g;

                    # deselect already selected customer users to prevent double selected users
                    for my $Item ( @TempArray ) {
                        $Item->{CustomerSelected} = '';
                    }

                    # get current user
                    if ( $TicketTemplate{$Key} eq '<KIX_CURRENT_USER>' ) {

                        # replace possible placeholder for agents
                        # get user preferences
                        my %UserData = $UserObject->GetUserData(
                            UserID => $Self->{UserID},
                        );

                        # get from
                        if (
                            $UserData{UserID}
                            && $UserData{UserEmail}
                            && $UserData{UserFullname}
                        ) {
                            $TicketTemplate{$Key}
                                = '"' . $UserData{UserFullname} . '" '
                                . '<' . $UserData{UserEmail} . '>';
                            $TicketTemplate{ $ExtKey . 'CustomerLogin' } = $UserData{UserLogin};
                        }
                    }
                    $Data{ 'QuickTicketCustomer' . $ExtKey }
                        = $TicketTemplate{ $ExtKey . 'CustomerLogin' } || '';

                    if (
                        !(
                            grep {
                                $_->{CustomerKey} eq
                                    $Data{ 'QuickTicketCustomer' . $ExtKey }
                            }
                            @TempArray
                        )
                        && !$IsUpload
                    ) {
                        $TempArrayCount++;
                        push @TempArray, {
                            Count            => $TempArrayCount,
                            CustomerElement  => $TicketTemplate{$Key},
                            CustomerSelected => 'checked="checked"',
                            CustomerKey      => $TicketTemplate{ $ExtKey . 'CustomerLogin' },
                            CustomerError    => '',
                            CustomerErrorMsg => 'CustomerGenericServerErrorMsg',
                            CustomerDisabled => '',
                        };
                    }

                    $Data{MultipleCustomer}    = \@TempArray if $Key eq 'From';
                    $Data{MultipleCustomerCc}  = \@TempArray if $Key eq 'Cc';
                    $Data{MultipleCustomerBcc} = \@TempArray if $Key eq 'Bcc';
                }
                elsif ( $TicketTemplate{ $Key . 'Empty' } ) {
                    @TempArray = ();
                    $Data{MultipleCustomer}    = \@TempArray if $Key eq 'From';
                    $Data{MultipleCustomerCc}  = \@TempArray if $Key eq 'Cc';
                    $Data{MultipleCustomerBcc} = \@TempArray if $Key eq 'Bcc';
                    $Data{CustomerID}          = ''          if $Key eq 'From';
                }

                last if $Self->{Action} eq 'AgentTicketPhone';
            }
        }

        # set default value for ticket type
        if ( $ConfigObject->Get('Ticket::Type') ) {
            if ( $TicketTemplate{TypeID} ) {
                if ( !$Data{TypeID} ) {
                    $Data{TypeID} = $TicketTemplate{TypeID};
                }
                elsif ( $Data{TypeID} && !$Self->{DefaultSetTypeChanged} ) {
                    $Data{TypeID} = $TicketTemplate{TypeID};
                }
                $Data{DefaultTypeID} = $TicketTemplate{TypeID};
            }
            elsif ( $TicketTemplate{TypeIDEmpty} ) {
                $Data{DefaultTypeID} = '';
                $Data{TypeID}        = '';
            }
            elsif ( $Data{TypeID} ) {
                $Data{DefaultTypeID} = $Data{TypeID};
            }
        }

        # set default value for queue
        if (
            !$Self->{QueueID}
            && $TicketTemplate{QueueID}
            && $TicketTemplate{QueueID} ne '-'
        ) {
            $Self->{QueueID} = $TicketTemplate{QueueID};
            my $DefaultQueueName = $QueueObject->QueueLookup(
                QueueID => $Self->{QueueID},
            );
            if ($DefaultQueueName) {
                $Data{DefaultQueueSelected} =
                    $Self->{QueueID} . "||" . $DefaultQueueName;
            }
        }
        elsif ( $TicketTemplate{QueueIDEmpty} ) {
            $Data{DefaultQueueSelected} = '';
        }
        elsif ( !$Self->{QueueID} && $Data{Dest} ) {
            $Data{DefaultQueueSelected} = $Data{Dest};
        }

        # set default value for priority
        if ( $TicketTemplate{PriorityID} ) {
            $Data{QuickTicketPriorityID} = $TicketTemplate{PriorityID};
            my $DefaultPrioName = $PriorityObject->PriorityLookup(
                PriorityID => $Data{QuickTicketPriorityID},
            );
            if ($DefaultPrioName) {
                $Data{QuickTicketPriority} = $DefaultPrioName;
            }
        }
        elsif ( $Data{PriorityID} ) {
            $Data{QuickTicketPriorityID} = $Data{PriorityID};
        }

        # get frontend to replace kix-tags
        my $Frontend;
        if ( $Self->{Action} eq 'CustomerTicketMessage' ) {
            $Frontend = 'Customer';
        }
        else {
            $Frontend = 'Agent';
        }

        # set default value for subject
        if ( $TicketTemplate{Subject} ) {
            $Data{QuickTicketSubject} = $TicketTemplate{Subject};
            $Data{QuickTicketSubject} = $TemplateGeneratorObject->ReplacePlaceHolder(
                Text     => $Data{QuickTicketSubject},
                Data     => {},
                RichText => 0,
                UserID   => $Self->{UserID},
                Frontend => $Frontend,
            );
        }
        elsif ( $TicketTemplate{SubjectEmpty} ) {
            $Data{QuickTicketSubject} = '';
        }
        elsif ( $Data{Subject} ) {
            $Data{QuickTicketSubject} = $Data{Subject};
        }

        # set default value for body
        if ( $TicketTemplate{Body} ) {
            $Data{QuickTicketBody}
                = $TicketTemplate{Body};
            $Data{QuickTicketBody}
                = $TemplateGeneratorObject->ReplacePlaceHolder(
                Text     => $Data{QuickTicketBody},
                Data     => {},
                RichText => $ConfigObject->Get('Frontend::RichText'),
                UserID   => $Self->{UserID},
                Frontend => $Frontend,
                );
        }
        elsif ( $TicketTemplate{BodyEmpty} ) {
            $Data{QuickTicketBody} = '';
        }
        elsif ( $Data{Body} ) {
            $Data{QuickTicketBody} = $Data{Body};
        }

        # set default value for state or keep get value
        if ( $TicketTemplate{StateID} ) {
            $Data{DefaultNextStateID} = $TicketTemplate{StateID};
            my %DefaultState = $StateObject->StateGet(
                ID => $Data{DefaultNextStateID},
            );
            if ( $DefaultState{Name} ) {
                $Data{DefaultNextState} = $DefaultState{Name};
            }
        }
        elsif ( $Data{NextStateID} ) {
            $Data{DefaultNextStateID} = $Data{NextStateID};
            my %DefaultState = $StateObject->StateGet(
                ID => $Data{DefaultNextStateID},
            );
            if ( $DefaultState{Name} ) {
                $Data{DefaultNextState} = $DefaultState{Name};
            }
        }

        # set default value for pending time
        if ( $TicketTemplate{PendingOffset} ) {
            my $TimeOffSet
                = $TicketTemplate{PendingOffset};
            $Data{DefaultPendingOffset} = 60 * int($TimeOffSet);
        }
        elsif (
            !$TicketTemplate{ServiceID}
            && (
                !defined $TicketTemplate{ServiceIDEmpty}
                || !$TicketTemplate{ServiceIDEmpty}
            )
        ) {
            $Data{QuickTicketServiceID} = '';
        }
        elsif ( $Data{PendingOffset} ) {
            $Data{DefaultPendingOffset} = $Data{PendingOffset};
        }

        # set default value for Service
        if ( $TicketTemplate{ServiceID} ) {
            $Data{QuickTicketServiceID}
                = $TicketTemplate{ServiceID};
        }
        elsif (
            !$TicketTemplate{ServiceID}
            && (
                !defined $TicketTemplate{ServiceIDEmpty}
                || !$TicketTemplate{ServiceIDEmpty}
            )
        ) {
            $Data{QuickTicketServiceID} = '';
        }
        elsif ( $TicketTemplate{ServiceIDEmpty} ) {
            $Data{QuickTicketServiceID} = '';
        }
        elsif ( $Data{ServiceID} ) {
            $Data{QuickTicketServiceID} = $Data{ServiceID};
        }

        # set default value for SLA
        if ( $TicketTemplate{SLAID} ) {
            $Data{QuickTicketSLAID} = $TicketTemplate{SLAID};
        }
        elsif ( $TicketTemplate{SLAIDEmpty} ) {
            $Data{QuickTicketSLAID} = '';
        }
        elsif ( $Data{SLAID} ) {
            $Data{QuickTicketSLAID} = $Data{SLAID};
        }

        # set default value for owner
        if ( $TicketTemplate{OwnerID} ) {
            $Data{QuickTicketOwnerID} = $TicketTemplate{OwnerID};
        }
        elsif ( $TicketTemplate{OwnerIDEmpty} ) {
            $Data{QuickTicketOwnerID} = '';
        }
        elsif ( $Data{OwnerID} ) {
            $Data{QuickTicketOwnerID} = $Data{OwnerID};
        }

        # set default value for responsible
        if ( $TicketTemplate{ResponsibleID} ) {
            $Data{QuickTicketResponsibleUserID} = $TicketTemplate{ResponsibleID};
        }
        elsif ( $TicketTemplate{ResponsibleIDEmpty} ) {
            $Data{QuickTicketResponsibleID} = '';
        }
        elsif ( $Data{ResponsibleID} ) {
            $Data{QuickTicketResponsibleID} = $Data{ResponsibleID};
        }

        # set default value for time accounting
        if ( $TicketTemplate{TimeUnits} ) {
            my $TimeUnits = $TicketTemplate{TimeUnits};
            $Data{QuickTicketTimeUnits} = int($TimeUnits);
        }
        elsif ( $TicketTemplate{TimeUnitsEmpty} ) {
            $Data{QuickTicketTimeUnits} = '';
        }
        elsif ( $Data{TimeUnits} ) {
            $Data{QuickTicketTimeUnits} = $Data{TimeUnits};
        }

        # set link direction (requires split action)
        if ( $TicketTemplate{LinkDirection} ) {
            $Self->{Config}->{SplitLinkType}->{Direction}
                = $TicketTemplate{LinkDirection};
        }
        elsif ( $Data{LinkDirection} ) {
            $Self->{Config}->{SplitLinkType}->{Direction} = $Data{LinkDirection};
        }

        # set link type (requires split action)
        if ( $TicketTemplate{LinkType} ) {
            $Self->{Config}->{SplitLinkType}->{LinkType}
                = $TicketTemplate{LinkType};
        }
        elsif ( $Data{LinkType} ) {
            $Self->{Config}->{SplitLinkType}->{LinkType} = $Data{LinkType};
        }

        # set article type
        if ( $TicketTemplate{ArticleType} ) {
            $Self->{Config}->{ArticleType}
                = $TicketObject
                ->ArticleTypeLookup( ArticleTypeID => $TicketTemplate{ArticleType} );
        }
        elsif ( $Data{ArticleType} ) {
            $Self->{Config}->{ArticleType} = $Data{ArticleType};
        }

        # set article sender type
        if ( $TicketTemplate{ArticleSenderType} ) {
            $Self->{Config}->{SenderType}
                = $TicketObject->ArticleSenderTypeLookup(
                SenderTypeID => $TicketTemplate{ArticleSenderType}
                );
        }
        elsif ( $Data{ArticleSenderType} ) {
            $Self->{Config}->{SenderType} = $Data{ArticleSenderType};
        }

        # set dynamic fields
        my %QuickTicketDynamicFieldHash;
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
            if ( $TicketTemplate{ 'DynamicField_' . $DynamicFieldConfig->{Name} } ) {
                $QuickTicketDynamicFieldHash{
                    'DynamicField_'
                        . $DynamicFieldConfig->{Name}
                    }
                    = $TicketTemplate{ 'DynamicField_' . $DynamicFieldConfig->{Name} };
            }
            elsif (
                $TicketTemplate{
                    'DynamicField_'
                        . $DynamicFieldConfig->{Name}
                        . 'Empty'
                }
            ) {
                $QuickTicketDynamicFieldHash{
                    'DynamicField_'
                        . $DynamicFieldConfig->{Name}
                    } = '';
            }
            elsif ( $Data{ 'DynamicField_' . $DynamicFieldConfig->{Name} } ) {
                $QuickTicketDynamicFieldHash{
                    'DynamicField_'
                        . $DynamicFieldConfig->{Name}
                    }
                    = ''
            }
        }
        $Data{QuickTicketDynamicFieldHash} = \%QuickTicketDynamicFieldHash;
    }

    return %Data;
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
