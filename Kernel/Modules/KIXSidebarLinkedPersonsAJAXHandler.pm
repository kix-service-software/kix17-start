# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarLinkedPersonsAJAXHandler;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LinkObject   = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $Result;

    for my $Needed (qw(CallingAction Subaction Frontend TicketID)) {
        $Param{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
        if ( !$Param{$Needed} ) {
            return $LayoutObject->ErrorScreen( Message => "Need $Needed!", );
        }
    }

    if ( $Param{Subaction} eq 'LoadLinkedPersons' ) {
        $LayoutObject->Block(
            Name => 'SidebarContent',
        );

        # get linked objects
        my $LinkListWithData = $LinkObject->LinkListWithData(
            Object  => 'Ticket',
            Key     => $Self->{TicketID},
            Object2 => 'Person',
            State   => 'Valid',
            UserID  => $Self->{UserID},
        );

        my $PersonRecipientTypes = $ConfigObject->Get('LinkedPerson::EmailRecipientTypes');
        my $InformPersonByMail   = $ConfigObject->Get('LinkedPerson::InformPersonByMail');
        my $SetAsCallContact     = $ConfigObject->Get('LinkedPerson::SetAsCallContact');

        my $CallContactActive = 0;
        if ( $Param{CallingAction} =~ /$SetAsCallContact/ && $ParamObject->GetParam( Param => 'CallContactActive' ) ) {
            $CallContactActive = 1;
            $LayoutObject->Block(
                Name => 'AsCallContactTitle',
            );
        }

        my $PersonInformTypes = 'InformPersonBy';
        $PersonInformTypes
            .= ( $Param{CallingAction} =~ /$InformPersonByMail/ )
            ? 'Mail'
            : 'Event';
        my %PersonDetails;

        if ( !$ConfigObject->Get('LinkedPerson::AllowNonAgentNotifyForInternalArticles') ) {
            $LayoutObject->Block(
                Name => 'NonAgentNotifyInformation',
            );
        }

        for my $LinkType ( sort keys %{ $LinkListWithData->{Person} } ) {
            next if !$LinkListWithData->{Person}->{$LinkType};
            next if !$LinkListWithData->{Person}->{$LinkType}->{Source};
            next if ref $LinkListWithData->{Person}->{$LinkType}->{Source} ne 'HASH';

            for my $UserID ( sort keys %{ $LinkListWithData->{Person}->{$LinkType}->{Source} } ) {
                my %PersonData = %{ $LinkListWithData->{Person}->{$LinkType}->{Source}->{$UserID} };

                # check for UserID
                next if (!$PersonData{UserID});

                # option to inform involved persons
                # build recipient selection
                my $PersonRecipientTypeStrg = $LayoutObject->BuildSelection(
                    Data         => $PersonRecipientTypes,
                    Name         => 'EmailRecipientType' . $UserID,
                    Class        => 'EmailRecipientType Modernize',
                    PossibleNone => 1,
                    Selected     => 0,
                    Title        => $LayoutObject->{LanguageObject}
                        ->Get('Add this person to list of recipients'),
                );
                $LayoutObject->Block(
                    Name => 'LinkedPerson',
                    Data => {
                        %PersonData,
                        LinkType => $LinkType,
                    },
                );
                $LayoutObject->Block(
                    Name => $PersonInformTypes,
                    Data => {
                        %PersonData,
                        UserType => $LinkType,
                        PersonRecipientTypeStrg => $PersonRecipientTypeStrg,
                    },
                );

                # show 'as call contact' checkbox
                if ( $CallContactActive ) {
                    if ( $LinkType ne 'Agent' ) {
                        $LayoutObject->Block(
                            Name => 'AsCallContact',
                            Data => \%PersonData,
                        );
                    } else {
                        $LayoutObject->Block(
                            Name => 'AsCallContact',
                            Data => { IsAgent => 1 },
                        );
                    }
                }

                # keep person data for person details
                $PersonDetails{$UserID} = \%PersonData;
            }
        }

        # person details
        my $DetailConfRef = $ConfigObject->Get('LinkedPerson::DetailKeys');
        for my $PersonData ( values %PersonDetails ) {
            last if !$DetailConfRef || ref($DetailConfRef) ne 'HASH';
            next if !$PersonData || ref($PersonData) ne 'HASH';

            # build div
            $LayoutObject->Block(
                Name => 'LinkedPersonDetails',
                Data => $PersonData,
            );
            for my $PersonKey ( sort keys %{$DetailConfRef} ) {
                my $Label = $DetailConfRef->{$PersonKey};
                my $Key   = $DetailConfRef->{$PersonKey};
                $Label =~ s/User//;
                if ( $PersonData->{$Key} ) {
                    $LayoutObject->Block(
                        Name => 'PersonData',
                        Data => {
                            Content => $PersonData->{$Key},
                            Label   => $Label,
                        },
                    );
                }
            }
        }

        # output result
        my $Template = 'AgentKIXSidebarLinkedPersons';
        if ( $Param{Frontend} eq 'Customer' ) {
            $Template = 'CustomerKIXSidebarLinkedPersons';
        }
        $Result = $LayoutObject->Output(
            TemplateFile => $Template,
        );
    }

    return $LayoutObject->Attachment(
        ContentType => 'text/plain; charset=' . $LayoutObject->{Charset},
        Content     => $Result || "<br/>",
        Type        => 'inline',
        NoCache     => 1,
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
