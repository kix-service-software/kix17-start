# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::PublicFAQZoom;

use strict;
use warnings;

use MIME::Base64 qw();
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # set UserID to root because in public interface there is no user
    $Self->{UserID} = 1;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get params
    my %GetParam;
    $GetParam{ItemID} = $ParamObject->GetParam( Param => 'ItemID' );

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check needed stuff
    if ( !$GetParam{ItemID} ) {
        return $LayoutObject->CustomerFatalError(
            Message => 'Need ItemID!',
        );
    }

    # get back link
    $GetParam{ZoomBackLink} = $ParamObject->GetParam( Param => 'ZoomBackLink' ) || '';
    if ( $GetParam{ZoomBackLink} ) {
        $GetParam{ZoomBackLink} = MIME::Base64::decode_base64( $GetParam{ZoomBackLink} );
    }

    # get FAQ object
    my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');

    # get FAQ item data
    my %FAQData = $FAQObject->FAQGet(
        ItemID     => $GetParam{ItemID},
        ItemFields => 1,
        UserID     => $Self->{UserID},
    );
    if ( !%FAQData ) {
        return $LayoutObject->CustomerFatalError();
    }

    # get the valid ids
    my @ValidIDs = $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet();
    my %ValidIDLookup = map { $_ => 1 } @ValidIDs;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get interface state list
    my $InterfaceStates = $FAQObject->StateTypeList(
        Types  => $ConfigObject->Get('FAQ::Public::StateTypes'),
        UserID => $Self->{UserID},
    );

    # permission check
    if (
        !$FAQData{Approved}
        || !$ValidIDLookup{ $FAQData{ValidID} }
        || !$InterfaceStates->{ $FAQData{StateTypeID} }
    ) {
        return $LayoutObject->CustomerNoPermission(
            WithHeader => 'yes',
        );
    }

    # ---------------------------------------------------------- #
    # HTMLView Sub-action
    # ---------------------------------------------------------- #
    if ( $Self->{Subaction} eq 'HTMLView' ) {

        # get params
        my $Field = $ParamObject->GetParam( Param => "Field" );

        # needed params
        for my $Needed (qw( ItemID Field )) {
            if ( !$Needed ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Needed Param: $Needed!",
                );
                return;
            }
        }

        # get the Field content
        my $FieldContent = $FAQObject->ItemFieldGet(
            ItemID => $GetParam{ItemID},
            Field  => $Field,
            UserID => $Self->{UserID},
        );

        # rewrite handle and action
        $FieldContent =~ s{ index[.]pl [?] Action=AgentFAQZoom }{public.pl?Action=PublicFAQZoom}gxms;

        # take care of old style before FAQ 2.0.x
        my $FieldPattern = 'index[.]pl [?] Action=AgentFAQ [&](amp;)? Subaction=Download [&](amp;)?';
        $FieldContent =~ s{$FieldPattern}{public.pl?Action=PublicFAQZoom;Subaction=DownloadAttachment;}gxms;

        # remove session from url
        $FieldContent =~ s{(Action=PublicFAQZoom;Subaction=DownloadAttachment;ItemID=\d+;FileID=\d+)[^"]*?"}{$1"}gxms;

        my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');

        # convert content to HTML if needed
        if (
            $Kernel::OM->Get('Kernel::Config')->Get('FAQ::Item::HTML')
            && $LayoutObject->{BrowserRichText}
            && $FAQData{ContentType} ne 'text/html'
        ) {
            $FieldContent = $HTMLUtilsObject->ToHTML(
                String => $FieldContent,
            ) || '';
        }

        # check if external sources should be removed from field content
        my $NoExtSrcLoad = 0;
        if ( $Kernel::OM->Get('Kernel::Config')->Get('Frontend::RemoveExternalSource') ) {
            $NoExtSrcLoad = 1;
        }

        # remove active HTML content (scripts, applets, etc...)
        my %SafeContent = $Kernel::OM->Get('Kernel::System::HTMLUtils')->Safety(
            String       => $FieldContent,
            NoApplet     => 1,
            NoObject     => 1,
            NoEmbed      => 1,
            NoIntSrcLoad => 0,
            NoExtSrcLoad => $NoExtSrcLoad,
            NoJavaScript => 1,
        );

        # take the safe content if necessary
        if ( $SafeContent{Replace} ) {
            $FieldContent = $SafeContent{String};
        }

        # detect all plain text links and put them into an HTML <a> tag
        $FieldContent = $HTMLUtilsObject->LinkQuote(
            String => $FieldContent,
        );

        # set target="_blank" attribute to all HTML <a> tags
        # the LinkQuote function needs to be called again
        $FieldContent = $HTMLUtilsObject->LinkQuote(
            String    => $FieldContent,
            TargetAdd => 1,
        );

        # add needed HTML headers
        $FieldContent = $HTMLUtilsObject->DocumentComplete(
            String  => $FieldContent,
            Charset => 'utf-8',
        );

        # build base URL for inline images
        my $SessionID = '';
        if ( $Self->{SessionID} && !$Self->{SessionIDCookie} ) {
            $SessionID = ';' . $Self->{SessionName} . '=' . $Self->{SessionID};
            $FieldPattern = '(Action=PublicFAQZoom;Subaction=DownloadAttachment;ItemID=\d+;FileID=\d+)';
            $FieldContent =~ s{$FieldPattern}{$1$SessionID}gmsx;
        }

        # return complete HTML as an attachment
        return $LayoutObject->Attachment(
            Type        => 'inline',
            ContentType => 'text/html',
            Content     => $FieldContent,
        );
    }

    # ---------------------------------------------------------- #
    # DownloadAttachment Sub-action
    # ---------------------------------------------------------- #
    if ( $Self->{Subaction} eq 'DownloadAttachment' ) {

        # manage parameters
        $GetParam{FileID} = $ParamObject->GetParam( Param => 'FileID' );
        if ( !defined $GetParam{FileID} ) {
            return $LayoutObject->CustomerFatalError(
                Message => 'Need FileID',
            );
        }

        # get attachments
        my %File = $FAQObject->AttachmentGet(
            ItemID => $GetParam{ItemID},
            FileID => $GetParam{FileID},
            UserID => $Self->{UserID},
        );
        if (%File) {
            return $LayoutObject->Attachment(
                %File,
            );
        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No such attachment ($GetParam{FileID})! May be an attack!!!",
            );
            return $LayoutObject->CustomerFatalError();
        }
    }

    # output header
    my $Output = $LayoutObject->CustomerHeader(
        Value => $FAQData{Title},
    );

    # set default interface settings
    my $Interface = $FAQObject->StateTypeGet(
        Name   => 'public',
        UserID => $Self->{UserID},
    );

    # prepare fields data
    my $FieldPattern = 'index[.]pl [?] Action=AgentFAQ [&](amp;)? Subaction=Download [&](amp;)?';
    FIELD:
    for my $Field (qw(Field1 Field2 Field3 Field4 Field5 Field6)) {
        next FIELD if !$FAQData{$Field};

        # rewrite links to embedded images for public interface
        if ( $Interface->{Name} eq 'public' ) {

            # rewrite handle and action
            $FAQData{$Field} =~ s{ index[.]pl [?] Action=AgentFAQZoom }{public.pl?Action=PublicFAQZoom}gxms;

            # take care of old style before FAQ 2.0.x
            $FAQData{$Field} =~ s{$FieldPattern}{public.pl?Action=PublicFAQZoom;Subaction=DownloadAttachment;}gxms;
        }

        # no quoting if HTML view is enabled
        next FIELD if $ConfigObject->Get('FAQ::Item::HTML');

        # HTML quoting
        $FAQData{$Field} = $LayoutObject->Ascii2Html(
            NewLine        => 0,
            Text           => $FAQData{$Field},
            VMax           => 5000,
            HTMLResultMode => 1,
            LinkFeature    => 1,
        );
    }

    # set voting results
    $Param{VotingResultColor} = $LayoutObject->GetFAQItemVotingRateColor(
        Rate => $FAQData{VoteResult},
    );

    if ( !$Param{VotingResultColor} || $FAQData{Votes} eq '0' ) {
        $Param{VotingResultColor} = 'Gray';
    }

    # show back link
    $LayoutObject->Block(
        Name => 'Back',
        Data => {
            %GetParam,
            %Param,
            %FAQData,
        },
    );

    # get multi-language option
    my $MultiLanguage = $ConfigObject->Get('FAQ::MultiLanguage');

    # show language
    if ($MultiLanguage) {
        $LayoutObject->Block(
            Name => 'Language',
            Data => {%FAQData},
        );
    }

    # get voting default option
    my $Voting = $ConfigObject->Get('FAQ::Voting');

    # show votes
    if ($Voting) {

        # always displays Votes result even if its 0
        $LayoutObject->Block(
            Name => 'ViewVotes',
            Data => {%FAQData},
        );
    }

    # show FAQ path
    my $ShowFAQPath = $LayoutObject->FAQPathShow(
        FAQObject   => $FAQObject,
        CategoryID  => $FAQData{CategoryID},
        PathForItem => 1,
        UserID      => $Self->{UserID},
    );
    if ($ShowFAQPath) {
        $LayoutObject->Block(
            Name => 'FAQPathItemElement',
            Data => {%FAQData},
        );
    }

    # show keywords as search links
    if ( $FAQData{Keywords} ) {

        # replace commas and semicolons
        $FAQData{Keywords} =~ s/,/ /g;
        $FAQData{Keywords} =~ s/;/ /g;

        my @Keywords = split /\s+/, $FAQData{Keywords};
        for my $Keyword (@Keywords) {
            $LayoutObject->Block(
                Name => 'Keywords',
                Data => {
                    Keyword => $Keyword,
                },
            );
        }
    }

    # output rating stars
    if ($Voting) {
        $LayoutObject->FAQRatingStarsShow(
            VoteResult => $FAQData{VoteResult},
            Votes      => $FAQData{Votes},
        );
    }

    # output attachments if any
    my @AttachmentIndex = $FAQObject->AttachmentIndex(
        ItemID     => $GetParam{ItemID},
        ShowInline => 0,
        UserID     => $Self->{UserID},
    );

    # output attachments
    if (@AttachmentIndex) {
        $LayoutObject->Block(
            Name => 'AttachmentHeader',
        );
        for my $Attachment (@AttachmentIndex) {
            $LayoutObject->Block(
                Name => 'AttachmentRow',
                Data => {
                    %FAQData,
                    %{$Attachment},
                },
            );
        }
    }

    # show message about links in iframes, if user didn't close it already, or sandbox is disabled
    if ( !$ConfigObject->Get('FAQ::Frontend::PublicDisableSandbox') ) {
        $LayoutObject->Block(
            Name => 'BrowserLinkMessage',
        );
    }

    # show FAQ Content
    $LayoutObject->FAQContentShow(
        FAQObject       => $FAQObject,
        InterfaceStates => $InterfaceStates,
        FAQData         => {%FAQData},
        UserID          => $Self->{UserID},
    );

    # get config of frontend module
    my $Config = $ConfigObject->Get("FAQ::Frontend::$Self->{Action}");

    # get the dynamic fields for this screen
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => 'FAQ',
        FieldFilter => $Config->{DynamicField} || {},
    );

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # cycle trough the activated Dynamic Fields for ticket object
    DYNAMICFIELDCONFIG:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELDCONFIG if !IsHashRefWithData($DynamicFieldConfig);

        my $Value = $DynamicFieldBackendObject->ValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $GetParam{ItemID},
        );

        # get print string for this dynamic field
        my $ValueStrg = $DynamicFieldBackendObject->DisplayValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Value,
            ValueMaxChars      => 250,
            LayoutObject       => $LayoutObject,
        );

        my $Label = $DynamicFieldConfig->{Label};

        $LayoutObject->Block(
            Name => 'FAQDynamicField',
            Data => {
                Label => $Label,
                Value => $ValueStrg->{Value},
                Title => $ValueStrg->{Title},
            },
        );

        # example of dynamic fields order customization
        $LayoutObject->Block(
            Name => 'FAQDynamicField_' . $DynamicFieldConfig->{Name},
            Data => {
                Label => $Label,
                Value => $ValueStrg->{Value},
                Title => $ValueStrg->{Title},
            },
        );
    }

    # log access to this FAQ item
    $FAQObject->FAQLogAdd(
        ItemID    => $ParamObject->GetParam( Param => 'ItemID' ),
        Interface => $Interface->{Name},
        UserID    => $Self->{UserID},
    );

    # start template output
    $Output .= $LayoutObject->Output(
        TemplateFile => 'PublicFAQZoom',
        Data         => {
            %FAQData,
            %GetParam,
            %Param,
        },
    );

    # add footer
    $Output .= $LayoutObject->CustomerFooter();

    return $Output;
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
