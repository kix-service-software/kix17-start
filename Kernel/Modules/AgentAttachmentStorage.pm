# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
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
    for my $Needed ( qw(AttachmentDirectoryID ConfigItemID) ) {
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
    my $AttributeKeyName   = "";
    my $XMLDefinition      = $VersionRef->{XMLDefinition};
    my $XMLData            = $VersionRef->{XMLData}->[1]->{Version}->[1];

    # check if requested AttachmentID is available as CIAttachment at all
    my $Attachments = $Self->{ConfigItemObject}->GetAttributeDataByType(
        XMLDefinition => $XMLDefinition,
        XMLData       => $XMLData,
        AttributeType => 'CIAttachment',
    );

    for my $CurrKey ( sort keys %{$Attachments} ) {
        next if ( ref( $Attachments->{$CurrKey}) ne 'ARRAY' );
        next if ( !scalar( @{$Attachments->{$CurrKey}} ) );

        if ( grep( { $GetParam{'AttachmentDirectoryID'} eq $_ } @{$Attachments->{$CurrKey}} ) ) {
            $IsAttachment     = 1;
            $AttributeKeyName = $CurrKey;
            last;
        }
    }

    $IsCustomerViewable = $Self->_CIAttributeIsCustomerViewable(
        XMLDefinition => $XMLDefinition,
        Key           => $AttributeKeyName,
    );

    if (
        $Self->{UserType} eq 'Customer'
        && !$IsCustomerViewable
    ) {
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

=item _CIAttributeIsCustomerViewable

returns if a CIattribute defined by its Key is customer visible. Note, that this is requires
the attribute key to be unique within the CI-class definition. It must not occur in various
document paths.

    my $IsCustomerVisible = _CIAttributeIsCustomerViewable(
       XMLDefinition => @SomeXMLDefinition,
       Key           => 'SomeKeyName',
    );

Returns:

    my $IsVisible = 0 || 1;

=cut

sub  _CIAttributeIsCustomerViewable {
    my ( $Self, %Param ) = @_;

    # check required params...
    return 0 if !$Param{Key};
    return 0 if !$Param{XMLDefinition};
    return 0 if ref $Param{XMLDefinition} ne 'ARRAY';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        if(
            $Item->{Key}
            && $Item->{Key} eq $Param{Key}
        ) {
            return $Item->{CustomerViewable} || '0';
        }

        # check if item should be shown in customer frontend
        next ITEM if !$Item->{CustomerViewable};

        if ( $Item->{Sub} ) {
            my $SubResult = $Self->_CIAttributeIsCustomerViewable (
                XMLDefinition => $Item->{Sub},
                Key           => $Param{Key},
            );

            return $SubResult if defined $SubResult;
        }
    }

    return;
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
