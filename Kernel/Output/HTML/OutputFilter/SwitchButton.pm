# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilter::SwitchButton;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    if ( !$Param{UserType} || ( $Param{UserType} ne 'User' && $Param{UserType} ne 'Customer' ) ) {
        return $Self;
    }

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    if ( !$Self->{UserType} || ( $Self->{UserType} ne 'User' && $Self->{UserType} ne 'Customer' ) ) {
        return $Self;
    }

    # create needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $CacheObject        = $Kernel::OM->Get('Kernel::System::Cache');
    my $GroupObject        = $Kernel::OM->Get('Kernel::System::Group');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %GroupList = $GroupObject->GroupList( Valid => 1, );
    my %ReverseGroupList = reverse(%GroupList);
    $Self->{GroupList}        = \%GroupList;
    $Self->{ReverseGroupList} = \%ReverseGroupList;

    # check data
    return if !$Param{Data};
    return if ref $Param{Data} ne 'SCALAR';
    return if !${ $Param{Data} };

    # get configuration for switch button...
    my $SwitchButtonReg = "";
    if ( $Self->{UserType} && $Self->{UserType} eq 'User' ) {
        $SwitchButtonReg = $ConfigObject->Get('Frontend::Module')->{SwitchButton} || '';
    }
    elsif ( $Self->{UserType} && $Self->{UserType} eq 'Customer' ) {
        $SwitchButtonReg = $ConfigObject->Get('CustomerFrontend::Module')->{SwitchButton}
            || '';
    }

    return if !$SwitchButtonReg;

    my $SwitchButtonTitle
        = $LayoutObject->{LanguageObject}->Translate( $SwitchButtonReg->{Title} );
    my $SwitchButtonDesc
        = $LayoutObject->{LanguageObject}->Translate( $SwitchButtonReg->{Description} );

    # check permission (may be from cache)
    my $Access = $CacheObject->Get(
        Type => 'SwitchButton_' . $Self->{UserType},
        Key  => 'Filter::Permission::' . $Self->{UserID},
    );

    # TODO: cache does not work correctly
    #return if ( defined $Access && !$Access );
    $Access = undef;
    if ( !defined $Access ) {
        $Access = 0;
        my $GroupAccess   = 1;
        my $GroupAccessRo = 1;
        my $Groups        = $SwitchButtonReg->{Group} || '';
        my $GroupsRo      = $SwitchButtonReg->{GroupRo} || '';

        # check or agent users...
        if ( $Self->{UserType} eq 'User' ) {

            # 1: check for valid customer account...
            my %CustomerData = $CustomerUserObject->CustomerUserDataGet(
                User => $Self->{UserLogin},
            );

            if (
                %CustomerData
                && $CustomerData{UserLogin}
                && (
                    !defined( $CustomerData{ValidID} )
                    || ( defined( $CustomerData{ValidID} ) && $CustomerData{ValidID} )
                )
            ) {
                $Access = 1;
            }

            # 2: check if Group restriction is enabled...
            if ( $Access && $Groups && ref($Groups) eq 'ARRAY' ) {
                $GroupAccess = 0;
                for my $Group ( @{$Groups} ) {
                    next
                        if (
                        !$LayoutObject->{"UserIsGroup[$Group]"} ||
                        $LayoutObject->{"UserIsGroup[$Group]"} ne 'Yes'
                        );
                    $GroupAccess = 1;
                    last;
                }
            }

            # 3: fallback: check if GroupRo restriction is enabled...
            elsif ( $Access && $GroupsRo && ref($GroupsRo) eq 'ARRAY' ) {
                $GroupAccess   = 0;
                $GroupAccessRo = 0;
                for my $Group ( @{$GroupsRo} ) {
                    next
                        if (
                        !$LayoutObject->{"UserIsGroupRo[$Group]"} ||
                        $LayoutObject->{"UserIsGroupRo[$Group]"} ne 'Yes'
                        );
                    $GroupAccessRo = 1;
                    last;
                }
            }

            $Access = $Access && ( $GroupAccess || $GroupAccessRo );
        }

        # check for customer users...
        elsif ( $Self->{UserType} eq 'Customer' ) {

            # 1: check for valid agent user account...
            my %Users = $UserObject->UserList(
                Valid => 1
            );

            my $IsAgent = 0;
            foreach ( keys %Users ) {
                last if $IsAgent;
                if ( $Users{$_} eq $Self->{UserLogin} ) { $IsAgent = 1; }
            }

            my %AgentData;

            if ($IsAgent) {
                %AgentData =
                    $UserObject->GetUserData( User => $Self->{UserLogin}, Valid => 1 );
                if ( %AgentData && $AgentData{UserLogin} ) {
                    $Access = 1;
                }
            }

            # 2: check if Group restriction is enabled...
            if ( $Access && $Groups && ref($Groups) eq 'ARRAY' ) {
                $GroupAccess = 0;
                my %GroupsHash = $GroupObject->GroupMemberList(
                    UserID => $AgentData{UserID},
                    Type   => 'rw',
                    Result => 'HASH',
                );
                my %ReverseGroups = reverse(%GroupsHash);
                for my $Group ( @{$Groups} ) {
                    next if !$Self->{ReverseGroupList}->{$Group} || !$ReverseGroups{$Group};
                    $GroupAccess = 1;
                    last;
                }
            }

            # 3: fallback: check if GroupRo restriction is enabled...
            elsif ( $Access && $GroupsRo && ref($GroupsRo) eq 'ARRAY' ) {
                $GroupAccess   = 0;
                $GroupAccessRo = 0;
                my %GroupsHash = $GroupObject->GroupMemberList(
                    UserID => $AgentData{UserID},
                    Type   => 'ro',
                    Result => 'HASH',
                );
                my %ReverseGroups = reverse(%GroupsHash);
                for my $Group ( @{$GroupsRo} ) {
                    next if !$Self->{ReverseGroupList}->{$Group} || !$ReverseGroups{$Group};
                    $GroupAccessRo = 1;
                    last;
                }
            }

            $Access = $Access && ( $GroupAccess || $GroupAccessRo );
        }
        else {
            $Access = 0;
        }

        # cache result
        $CacheObject->Set(
            Type  => 'SwitchButton_' . $Self->{UserType},
            Key   => 'Filter::Permission::' . $Self->{UserID},
            Value => $Access,
            TTL   => 60 * 60,
        );
        return if !$Access;
    }

    # check if output contains logout button
    my $AgentPattern    = '<a class="LogoutButton" id="LogoutButton"';
    my $CustomerPattern = '\s*<li class="Last".*?Action=Logout';

    # add switch button link to exisitng logout link in customer frontend
    if ( ${ $Param{Data} } =~ /$CustomerPattern/g ) {
        my $SwitchLink = $LayoutObject->{Baselink} . 'Action=SwitchButton&Type=Agent';
        my $Replace    = <<"END";
          <li><a href=\"$SwitchLink\" title=\"$SwitchButtonDesc\">$SwitchButtonTitle</a></li>
END
        $Replace = $LayoutObject->Output(
            Template => $Replace,
        );
        ${ $Param{Data} } =~ s/($CustomerPattern)/$Replace$1/g;
    }

    # add switch button link to exisitng logout link in agent frontend
    elsif ( ${ $Param{Data} } =~ /$AgentPattern/g ) {

        my $SwitchLink = $LayoutObject->{Baselink} . 'Action=SwitchButton&Type=Customer';
        my $Replace    = <<"END";
          <a href=\"$SwitchLink\" id=\"SwitchButton\" class=\"SwitchButton\" title=\"$SwitchButtonDesc\"><i class="fa fa-exchange"></i></a>
END
        $Replace = $LayoutObject->Output(
            Template => $Replace,
        );
        ${ $Param{Data} } =~ s/($AgentPattern)/$Replace$1/g;
    }
    return 1;
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
