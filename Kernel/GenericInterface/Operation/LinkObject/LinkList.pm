# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Operation::LinkObject::LinkList;

use strict;
use warnings;

use base qw(Kernel::GenericInterface::Operation::Common);
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::LinkObject::LinkList - GenericInterface Link List Operation backend

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

            Object    => 'Ticket',
            Key       => '321',
            Object2   => 'FAQ',         # (optional)
            State     => 'Valid',
            Type      => 'ParentChild', # (optional)
            Direction => 'Target',      # (optional) default Both      (Source|Target|Both)
        },
    );

    $Result = {
        Success => 1,          # 0 or 1

        Data => {
            Ticket => {
                Normal => {
                    Source => {
                        12  => 1,
                        212 => 1,
                        332 => 1,
                    },
                },
                ParentChild => {
                    Source => {
                        5 => 1,
                        9 => 1,
                    },
                    Target => {
                        4  => 1,
                        8  => 1,
                        15 => 1,
                    },
                },
            },
            FAQ => {
                ParentChild => {
                    Source => {
                        5 => 1,
                    },
                },
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
            ErrorCode    => 'LinkList.MissingParameter',
            ErrorMessage => 'The request is empty!',
        );
    }

    for my $Needed ( qw(Object Key State) ) {
        # check needed stuff
        if ( !$Param{Data}->{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => 'LinkList.MissingParameter',
                ErrorMessage => 'Got no ' . $Needed . '!',
            );
        } else {
            $GetParam{$Needed} = $Param{Data}->{$Needed};
        }
    }

    for my $Optional ( qw(Object2 Type Direction) ) {
        # get optional parameter
        if ( $Param{Data}->{ $Optional } ) {
            $GetParam{ $Optional } = $Param{Data}->{ $Optional };
        }
    }

    # check needed stuff
    if (
        !$Param{Data}->{UserLogin}
        && !$Param{Data}->{SessionID}
    ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkList.MissingParameter',
            ErrorMessage => 'UserLogin or SessionID is required!',
        );
    }

    if (
        $Param{Data}->{UserLogin}
        && !$Param{Data}->{Password}
    ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkList.MissingParameter',
            ErrorMessage => 'Password for UserLogin is required!',
        );
    }

    # authenticate user
    my ( $UserID, $UserType ) = $Self->Auth(
        %Param,
    );

    if ( !$UserID ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkList.AuthFail',
            ErrorMessage => 'User could not be authenticated!',
        );
    }

    # check user type
    if (
        !$UserType
        || $UserType ne 'User'
    ) {
        return $Self->ReturnError(
            ErrorCode    => 'LinkList.AuthFail',
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
                ErrorCode    => 'LinkList.AuthFail',
                ErrorMessage => 'Authentification with user in group "admin" and "rw" permission required!',
            );
        }
    }

    # get link list
    my $LinkList = $LinkObject->LinkList(
        %GetParam,
        UserID => $UserID,
    );

    if ( ref( $LinkList ) ne 'HASH' ) {
        # get error message
        my $ErrorMessage = $Kernel::OM->Get('Kernel::System::Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        return $Self->ReturnError(
            ErrorCode    => 'LinkAdd.LinkListError',
            ErrorMessage => ( $ErrorMessage || 'Could not get link list!' ),
        );
    }

    return {
        Success => 1,
        Data    => $LinkList,
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
