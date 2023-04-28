# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Operation::LinkObject::LinkDeleteAll;

use strict;
use warnings;

use base qw(Kernel::GenericInterface::Operation::Common);
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::LinkObject::LinkDeleteAll - GenericInterface Link Delete All Operation backend

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
            UserLogin         => 'some agent login',                            # UserLogin or SessionID (of agent in group 'admin' with permission 'rw') is required
            SessionID         => 123,

            Password  => 'some password',                                       # if UserLogin is sent then Password is required

            Object => 'Ticket',
            Key    => '321',
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
            ErrorCode    => 'LinkDeleteAll.MissingParameter',
            ErrorMessage => 'The request is empty!',
        );
    }

    for my $Needed ( qw(Object Key) ) {
        # check needed stuff
        if ( !$Param{Data}->{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => 'LinkDeleteAll.MissingParameter',
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
    ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkDeleteAll.MissingParameter',
            ErrorMessage => 'UserLogin or SessionID is required!',
        );
    }

    if (
        $Param{Data}->{UserLogin}
        && !$Param{Data}->{Password}
    ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkDeleteAll.MissingParameter',
            ErrorMessage => 'Password for UserLogin is required!',
        );
    }

    # authenticate user
    my ( $UserID, $UserType ) = $Self->Auth(
        %Param,
    );

    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkDeleteAll.AuthFail',
            ErrorMessage => 'User could not be authenticated!',
        );
    }

    # check user type
    if (
        !$UserType
        || $UserType ne 'User'
    ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkDeleteAll.AuthFail',
            ErrorMessage => 'Authentification with user type "User" required!',
        );
    }

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');
    my $LinkObject   = $Kernel::OM->Get('Kernel::System::LinkObject');

    # check if admin permission is required
    if ($ConfigObject->Get('GenericInterface::Operation::LinkObject::RequireAdminPermission')) {
        # get group id of group 'admin'
        my $GroupID = $GroupObject->GroupLookup(
            Group => 'admin',
        );

        # get users with 'rw' permission on group 'admin'
        my %UserList = $GroupObject->PermissionGroupUserGet(
            GroupID => $GroupID,
            Type    => 'rw',
        );

        # check if user is in group 'admin' with 'rw' permission
        if ( !$UserList{ $UserID } ) {
            return $Self->ReturnError(
                ErrorCode    => 'LinkDeleteAll.AuthFail',
                ErrorMessage => 'Authentification with user in group "admin" and "rw" permission required!',
            );
        }
    }

    # delete all links
    my $Success = $LinkObject->LinkDeleteAll(
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
            ErrorCode    => 'LinkDeleteAll.LinkDeleteAllError',
            ErrorMessage => ( $ErrorMessage || 'Could not delete link!' ),
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
