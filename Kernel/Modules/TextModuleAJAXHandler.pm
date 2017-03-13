# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::TextModuleAJAXHandler;

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
    my $TextModuleObject = $Kernel::OM->Get('Kernel::System::TextModule');
    my $TicketObject     = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject      = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $Result;

    for my $Needed (qw(Subaction Frontend)) {
        $Param{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
        if ( !$Param{$Needed} ) {
            return $LayoutObject->ErrorScreen( Message => "Need $Needed!", );
        }
    }

    if ( $Param{Subaction} eq 'LoadTextModules' ) {

        # get params
        for (qw(TypeID QueueID TicketID StateID CustomerUserID)) {
            if ( $ParamObject->GetParam( Param => $_ ) ne 'undefined' ) {
                $Param{$_} = $ParamObject->GetParam( Param => $_ ) || '';
            }
            else {
                $Param{$_} = '';
            }
        }

        my %Ticket;
        if ( $Param{TicketID} && $Param{TicketID} ne 'undefined' ) {
            %Ticket = $TicketObject->TicketGet(
                TicketID      => $Param{TicketID},
                DynamicFields => 1,
            );
        }

        my $CustomerUser;
        if ( $Param{Frontend} eq 'Customer' ) {
            $CustomerUser = $Self->{UserID};
        }
        elsif ( $Param{CustomerUserID} ) {
            $CustomerUser = $Param{CustomerUserID};
        }

        $Result = $LayoutObject->ShowAllTextModules(
            %Ticket,
            UserLastname   => $Self->{UserLastname},
            UserFirstname  => $Self->{UserFirstname},
            TicketTypeID   => $Param{TypeID} || $Ticket{TypeID},
            QueueID        => $Param{QueueID} || $Ticket{QueueID},
            TicketStateID  => $Param{StateID} || $Ticket{StateID},
            Customer       => ( $Param{Frontend} eq 'Customer' ) ? '1' : '',
            Public         => ( $Param{Frontend} eq 'Public' ) ? '1' : '',
            Agent          => ( $Param{Frontend} eq 'Agent' ) ? '1' : '',
            UserID         => ( $Param{Frontend} eq 'Agent' ) ? $Self->{UserID} : '',
            CustomerUserID => $CustomerUser,
        );
    }
    elsif ( $Param{Subaction} eq 'LoadTextModule' ) {

        # get params
        for (qw(ID TypeID QueueID TicketID CustomerUserID)) {
            $Param{$_} = $ParamObject->GetParam( Param => $_ ) || '';
        }

        my %Ticket;
        if ( $Param{TicketID} && $Param{TicketID} ne 'undefined' ) {
            %Ticket = $TicketObject->TicketGet(
                TicketID      => $Param{TicketID},
                DynamicFields => 1,
            );
        }

        my $CustomerUser = $Ticket{CustomerUserID};
        if ( $Param{Frontend} eq 'Customer' ) {
            $CustomerUser = $Self->{UserID};
        }
        elsif ( $Param{CustomerUserID} ) {
            $CustomerUser = $Param{CustomerUserID};
        }

        # load TextModule
        my %TextModule = $TextModuleObject->TextModuleGet(
            ID => $Param{ID},
        );

        %TextModule = $Self->_LoadTextModule(
            %Ticket,
            TextModule    => \%TextModule,
            UserLastname  => $Self->{UserLastname},
            UserFirstname => $Self->{UserFirstname},
            TicketTypeID  => $Param{TypeID} || $Ticket{TypeID},
            QueueID       => $Param{QueueID} || $Ticket{QueueID},
            Customer      => ( $Param{Frontend} eq 'Customer' ) ? '1' : '',
            Public        => ( $Param{Frontend} eq 'Public' ) ? '1' : '',
            UserID        => ( $Param{Frontend} eq 'Agent' ) ? $Self->{UserID} : '',
            Data          => {
                CustomerUserID => $CustomerUser,
            },
            Frontend => $Param{Frontend},
        );

        # build JSON output
        $Result = $LayoutObject->JSONEncode(
            Data => {
                %TextModule,
            },
        );
    }

    return $LayoutObject->Attachment(
        ContentType => 'text/plain; charset=' . $LayoutObject->{Charset},
        Content     => $Result || "<br/>",
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _LoadTextModule {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::TemplateGenerator');
    my $ConfigObject            = $Kernel::OM->Get('Kernel::Config');

    my %TextModule = %{ $Param{TextModule} };
    my $RichText   = $ConfigObject->Get('Frontend::RichText');

    return %TextModule if $Param{NoReplace};

    # replace placeholder in text and subject
    for my $DataKey (qw(TextModule Subject)) {

        next if !defined $TextModule{$DataKey};

        $TextModule{$DataKey} = $TemplateGeneratorObject->ReplacePlaceHolder(
            Text     => $TextModule{$DataKey},
            Data     => $Param{Data},
            RichText => ( $DataKey eq 'TextModule' ) ? $RichText : 0,
            UserID   => $Self->{UserID},
            TicketID => $Param{TicketID} || 0,
            Frontend => $Param{Frontend},
        );
    }

    $TextModule{Subject}    = '' if !$TextModule{Subject};
    $TextModule{TextModule} = '' if !$TextModule{TextModule};

    return %TextModule;
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
