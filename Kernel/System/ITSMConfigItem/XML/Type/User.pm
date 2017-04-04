# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::User;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::User'
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::User - xml backend module

=head1 SYNOPSIS

All xml functions of User objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $XMLTypeDummyBackendObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem::XML::Type::User');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{LogObject}  = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{UserObject} = $Kernel::OM->Get('Kernel::System::User');

    return $Self;
}

=item ValueLookup()

get the xml data of a version

    my $Value = $BackendObject->ValueLookup(
        Value => 11, # (optional)
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    return '' if !$Param{Value};

    # get User data
    my %UserSearchList = $Self->{UserObject}->GetUserData(
        UserID => $Param{Value},
    );
    my $UserName = '';
    if (%UserSearchList) {
        $UserName = '"'
            . $UserSearchList{UserFirstname} . ' '
            . $UserSearchList{UserLastname} . '" <'
            . $UserSearchList{UserEmail} . '>';
    }

    return $UserName || '';

}

=item StatsAttributeCreate()

create a attribute array for the stats framework

    my $Attribute = $BackendObject->StatsAttributeCreate(
        Key => 'Key::Subkey',
        Name => 'Name',
        Item => $ItemRef,
    );

=cut

sub StatsAttributeCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Name Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # create arrtibute
    my $Attribute = [
        {
            Name             => $Param{Name},
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => $Param{Key},
            Block            => 'InputField',
        },
    ];

    return $Attribute;
}

=item ExportSearchValuePrepare()

prepare search value for export

    my $ArrayRef = $BackendObject->ExportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    my %UserData = $Self->{UserObject}->GetUserData(
        UserID => $Param{Value},
    );

    $Self->{LogObject}->Log(
        Priority => 'error',
        Message  => "No user found for ID <$Param{Value}>!"
    );

    return $Param{Value};
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    my %UserData = $Self->{UserObject}->GetUserData(
        UserID => $Param{Value},
    );

    $Self->{LogObject}->Log(
        Priority => 'error',
        Message  => "No user found for ID <$Param{Value}>!"
    );

    return $UserData{UserLogin} || '';
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    my %UserData = $Self->{UserObject}->GetUserData(
        User => $Param{Value},
    );

    if ( !$UserData{UserID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "No user found for login <$Param{Value}>!"
        );
        return;
    }

    return $UserData{UserID};
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    my %UserData = $Self->{UserObject}->GetUserData(
        User => $Param{Value},
    );

    if ( !$UserData{UserID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "No user found for login <$Param{Value}>!"
        );
        return;
    }

    return $UserData{UserID};
}

1;


=head1 VERSION

$Revision$ $Date$

=cut



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
