# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentAttachmentStorage;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CIAttachmentStorage::AttachmentStorage',
    'Kernel::System::Log',
    'Kernel::System::Web::Request',
    'Kernel::System::ITSMConfigItem'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{LayoutObject}            = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{AttachmentStorageObject} = $Kernel::OM->Get('Kernel::System::CIAttachmentStorage::AttachmentStorage');
    $Self->{LogObject}               = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ParamObject}             = $Kernel::OM->Get('Kernel::System::Web::Request');
    $Self->{ConfigItemObject}        = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my %GetParam;
    my $Access = 0;

    # check params...
    for my $Needed ( qw(AttachmentDirectoryID ConfigItemID) )  {
        $GetParam{$Needed} = $Self->{ParamObject}->GetParam( Param => $Needed ) || '';
        if ( !$GetParam{$Needed} ) {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "AgentAttachmentStorage: Need $Needed!",
                Comment => 'Please contact the admin.',
            );
        }
    }

    # get version data of the config item
    my $VersionRef = $Self->{ConfigItemObject}->VersionGet(
        ConfigItemID => $GetParam{ConfigItemID},
        XMLDataGet   => 1,
    );

    if ( !$VersionRef ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "ConfigItem (ID: $GetParam{ConfigItemID}) dosen't exists! ",
            Comment => 'Please contact the admin.',
        );
    }

    # get config item permission
    if ( $Self->{UserType} eq 'Customer' ) {
        $Access = $Self->{ConfigItemObject}->CustomerPermission(
            Type     => 'ro',
            Scope    => 'Item',
            ItemID   => $GetParam{ConfigItemID},
            UserID   => $Self->{UserID},
        );
    }

    else {
        $Access = $Self->{ConfigItemObject}->Permission(
            Type     => 'ro',
            Scope    => 'Item',
            ItemID   => $GetParam{ConfigItemID},
            UserID   => $Self->{UserID},
        );
    }

    if ( !$Access ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => 'No access is given!',
            Comment => 'Please contact the admin.',
        );
    }

    my $IsCustomerViewable = 1;
    my $IsAttachment       = 0;
    my $XMLDefinition      = $VersionRef->{XMLDefinition};
    my $XMLData            = $VersionRef->{XMLData}->[1]->{Version}->[1];

    # searches for the CIAttachment attribute
    ATTRIBUTE:
    for my $Attribute ( @{$XMLDefinition} ) {
        next ATTRIBUTE if $Attribute->{Input}->{Type} ne 'CIAttachment';
        next ATTRIBUTE if !defined $XMLData->{$Attribute->{Key}};

        # checks if AttachmentDirectoryID is stored in the ConfigItem
        ENTRY:
        for my $Entry ( @{$XMLData->{$Attribute->{Key}}} ) {
            next ENTRY if !defined $Entry;
            next ENTRY if $Entry->{Content} ne $GetParam{AttachmentDirectoryID};

            $IsCustomerViewable = 0 if $Self->{UserType} eq 'Customer' && !$Attribute->{CustomerViewable};
            $IsAttachment       = 1;
        }
    }

    # if CustomerViewable set for customer
    if ( !$IsCustomerViewable ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "No access is given to download attachment!",
            Comment => 'Please contact the admin.',
        );
    }

    # if attachment exists in ConfigItem
    if ( !$IsAttachment ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "No such attachment (ID: $GetParam{AttachmentDirectoryID}) in ConfigItem (ID: $GetParam{ConfigItemID})!",
            Comment => 'Please contact the admin.',
        );
    }

    # get the attachment...
    my %AttachmentData = %{
        $Self->{AttachmentStorageObject}->AttachmentStorageGet(
            ID => $GetParam{AttachmentDirectoryID},
        )
    };

    if (%AttachmentData) {
        $AttachmentData{Content}     = ${ $AttachmentData{ContentRef} };
        $AttachmentData{Filename}    = $AttachmentData{FileName};
        $AttachmentData{ContentType} = $AttachmentData{Preferences}->{DataType};
        return $Self->{LayoutObject}->Attachment(%AttachmentData);
    }

    else {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "No such attachment in directory index (ID: $GetParam{AttachmentDirectoryID})! ",
            Comment => 'Please contact the admin.',
        );
    }
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
