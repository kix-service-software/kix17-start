#!/usr/bin/perl
# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

# use ../../ as lib location
use FindBin qw($Bin);
use lib "$Bin/../..";
use lib "$Bin/../../Kernel/cpan-lib";
use lib "$Bin/../../Custom";

use SOAP::Transport::HTTP;
use Kernel::System::ObjectManager;

SOAP::Transport::HTTP::CGI->dispatch_to('Core')->handle();

package Core;

sub new {
    my $Self = shift;

    my $Class = ref($Self) || $Self;
    bless {} => $Class;

    return $Self;
}

sub Dispatch {
    my ( $Self, $User, $Pw, $Object, $Method, %Param ) = @_;

    $User ||= '';
    $Pw   ||= '';
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'Kernel::System::Log' => {
            LogPrefix => 'KIX-RPC',
        },
    );

    my %CommonObject;

    $CommonObject{ConfigObject}          = $Kernel::OM->Get('Kernel::Config');
    $CommonObject{CustomerCompanyObject} = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    $CommonObject{CustomerUserObject}    = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $CommonObject{EncodeObject}          = $Kernel::OM->Get('Kernel::System::Encode');
    $CommonObject{GroupObject}           = $Kernel::OM->Get('Kernel::System::Group');
    $CommonObject{LinkObject}            = $Kernel::OM->Get('Kernel::System::LinkObject');
    $CommonObject{LogObject}             = $Kernel::OM->Get('Kernel::System::Log');
    $CommonObject{MainObject}            = $Kernel::OM->Get('Kernel::System::Main');
    $CommonObject{PIDObject}             = $Kernel::OM->Get('Kernel::System::PID');
    $CommonObject{QueueObject}           = $Kernel::OM->Get('Kernel::System::Queue');
    $CommonObject{SessionObject}         = $Kernel::OM->Get('Kernel::System::AuthSession');
    $CommonObject{TicketObject}          = $Kernel::OM->Get('Kernel::System::Ticket');
    $CommonObject{TimeObject}            = $Kernel::OM->Get('Kernel::System::Time');
    $CommonObject{UserObject}            = $Kernel::OM->Get('Kernel::System::User');

    my $RequiredUser     = $CommonObject{ConfigObject}->Get('SOAP::User');
    my $RequiredPassword = $CommonObject{ConfigObject}->Get('SOAP::Password');

    if (
        !defined $RequiredUser
        || !length $RequiredUser
        || !defined $RequiredPassword || !length $RequiredPassword
        )
    {
        $CommonObject{LogObject}->Log(
            Priority => 'notice',
            Message  => "SOAP::User or SOAP::Password is empty, SOAP access denied!",
        );
        return;
    }

    if ( $User ne $RequiredUser || $Pw ne $RequiredPassword ) {
        $CommonObject{LogObject}->Log(
            Priority => 'notice',
            Message  => "Auth for user $User (pw $Pw) failed!",
        );
        return;
    }

    if ( !$CommonObject{$Object} ) {
        $CommonObject{LogObject}->Log(
            Priority => 'error',
            Message  => "No such Object $Object!",
        );
        return "No such Object $Object!";
    }

    return $CommonObject{$Object}->$Method(%Param);
}

=item DispatchMultipleTicketMethods()

to dispatch multiple ticket methods and get the TicketID

    my $TicketID = $RPC->DispatchMultipleTicketMethods(
        $SOAP_User,
        $SOAP_Pass,
        'TicketObject',
        [ { Method => 'TicketCreate', Parameter => \%TicketData }, { Method => 'ArticleCreate', Parameter => \%ArticleData } ],
    );

=cut

sub DispatchMultipleTicketMethods {
    my ( $Self, $User, $Pw, $Object, $MethodParamArrayRef ) = @_;

    $User ||= '';
    $Pw   ||= '';

    # common objects
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'Kernel::System::Log' => {
            LogPrefix => 'KIX-RPC',
        },
    );

    my %CommonObject;

    $CommonObject{ConfigObject}          = $Kernel::OM->Get('Kernel::Config');
    $CommonObject{CustomerCompanyObject} = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    $CommonObject{CustomerUserObject}    = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $CommonObject{EncodeObject}          = $Kernel::OM->Get('Kernel::System::Encode');
    $CommonObject{GroupObject}           = $Kernel::OM->Get('Kernel::System::Group');
    $CommonObject{LinkObject}            = $Kernel::OM->Get('Kernel::System::LinkObject');
    $CommonObject{LogObject}             = $Kernel::OM->Get('Kernel::System::Log');
    $CommonObject{MainObject}            = $Kernel::OM->Get('Kernel::System::Main');
    $CommonObject{PIDObject}             = $Kernel::OM->Get('Kernel::System::PID');
    $CommonObject{QueueObject}           = $Kernel::OM->Get('Kernel::System::Queue');
    $CommonObject{SessionObject}         = $Kernel::OM->Get('Kernel::System::AuthSession');
    $CommonObject{TicketObject}          = $Kernel::OM->Get('Kernel::System::Ticket');
    $CommonObject{TimeObject}            = $Kernel::OM->Get('Kernel::System::Time');
    $CommonObject{UserObject}            = $Kernel::OM->Get('Kernel::System::User');

    my $RequiredUser     = $CommonObject{ConfigObject}->Get('SOAP::User');
    my $RequiredPassword = $CommonObject{ConfigObject}->Get('SOAP::Password');

    if (
        !defined $RequiredUser
        || !length $RequiredUser
        || !defined $RequiredPassword || !length $RequiredPassword
        )
    {
        $CommonObject{LogObject}->Log(
            Priority => 'notice',
            Message  => "SOAP::User or SOAP::Password is empty, SOAP access denied!",
        );
        return;
    }

    if ( $User ne $RequiredUser || $Pw ne $RequiredPassword ) {
        $CommonObject{LogObject}->Log(
            Priority => 'notice',
            Message  => "Auth for user $User (pw $Pw) failed!",
        );
        return;
    }

    if ( !$CommonObject{$Object} ) {
        $CommonObject{LogObject}->Log(
            Priority => 'error',
            Message  => "No such Object $Object!",
        );
        return "No such Object $Object!";
    }

    my $TicketID;
    my $Counter;

    for my $MethodParamEntry ( @{$MethodParamArrayRef} ) {

        my $Method    = $MethodParamEntry->{Method};
        my %Parameter = %{ $MethodParamEntry->{Parameter} };

        # push ticket id to params if there is no ticket id
        if ( !$Parameter{TicketID} && $TicketID ) {
            $Parameter{TicketID} = $TicketID;
        }

        my $ReturnValue = $CommonObject{$Object}->$Method(%Parameter);

        # remember ticket id if method was TicketCreate
        if ( !$Counter && $Object eq 'TicketObject' && $Method eq 'TicketCreate' ) {
            $TicketID = $ReturnValue;
        }

        $Counter++;
    }

    return $TicketID;
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
