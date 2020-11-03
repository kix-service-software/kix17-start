# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Operation::LinkObject::LinkAdd;

use strict;
use warnings;

use base qw(Kernel::GenericInterface::Operation::Common);
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::LinkObject::LinkAdd - GenericInterface Link Create Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::GenericInterface::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item Run()

Create a new link.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',                            # UserLogin or SessionID (of agent) is required
            SessionID         => 123,

            Password  => 'some password',                                       # if UserLogin is sent then Password is required

            SourceObject => 'Ticket',
            SourceKey    => '123',
            TargetObject => 'ITSMConfigItem',
            TargetKey    => '123',
            Type         => 'ParentChild',
            State        => 'Valid',
        },
    );

    $Result = {
        Success => 1,          # 0 or 1

        Data => {
            # In case of success
            Success => 1

            # In case of an error
            Error => {
                ErrorCode    => $ErrorCode,
                ErrorMessage => $ErrorMessage
            }
        }
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my %GetParam;

    # check needed stuff
    if ( !IsHashRefWithData( $Param{Data} ) ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkAdd.MissingParameter',
            ErrorMessage => 'The request is empty!',
        );
    }

    for my $Needed ( qw(SourceObject SourceKey TargetObject TargetKey Type State) ) {
        # check needed stuff
        if ( !$Param{Data}->{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => 'LinkAdd.MissingParameter',
                ErrorMessage => 'Got no ' . $Needed . '!',
            );
        } else {
            $GetParam{$Needed} = $Param{Data}->{$Needed};
        }
    }

    # check needed stuff
    if (
        !$Param{Data}->{UserLogin}
        && !$Param{Data}->{SessionID}
        )
    {
        return $Self->ReturnError(
            ErrorCode    => 'LinkAdd.MissingParameter',
            ErrorMessage => 'UserLogin or SessionID is required!',
        );
    }

    if ( $Param{Data}->{UserLogin} && !$Param{Data}->{Password} ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkAdd.MissingParameter',
            ErrorMessage => 'Password for UserLogin is required!',
        );
    }

    # authenticate user
    my ( $UserID, $UserType ) = $Self->Auth(
        %Param,
    );

    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkAdd.AuthFail',
            ErrorMessage => 'User could not be authenticated!',
        );
    }

    # check user type
    if (
        !$UserType
        || $UserType ne 'User'
    ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkAdd.AuthFail',
            ErrorMessage => 'Authentification with user type "User" required!',
        );
    }

    # get needed objects
    my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');

    # check link type
    my $TypeID = $LinkObject->TypeLookup(
        Name   => $GetParam{Type},
        UserID => $UserID,
    );
    if ( !$TypeID ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkAdd.InvalidParameter',
            ErrorMessage => 'Type doesn\'t exists!',
        );
    }

    # check link state
    my $StateID = $LinkObject->StateLookup(
        Name   => $GetParam{State},
    );
    if ( !$StateID ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkAdd.InvalidParameter',
            ErrorMessage => 'State doesn\'t exists!',
        );
    }

    # create link
    my $Success = $LinkObject->LinkAdd(
        %GetParam,
        UserID => $UserID,
    );

    if ( !$Success ) {
        # get error message
        my $ErrorMessage = $Kernel::OM->Get('Kernel::System::Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        return $Self->ReturnError(
            ErrorCode    => 'LinkAdd.LinkAddError',
            ErrorMessage => ( $ErrorMessage || 'Could not create link!' ),
        );
    }

    return {
        Success => 1,
        Data    => {
            Success => $Success,
        },
    };
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
