# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilter::TicketPrintRichtext;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get user infos
    $Self->{UserID}    = $Param{UserID}    || '';
    $Self->{UserLogin} = $Param{UserLogin} || '';
    $Self->{UserType}  = $Param{UserType}  || '';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check data
    return if !$Param{Data};
    return if ref $Param{Data} ne 'SCALAR';
    return if !${ $Param{Data} };
    return if !$Param{TemplateFile};

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    return if !$LayoutObject->{EnvRef}->{Action}
            || $LayoutObject->{EnvRef}->{Action} eq 'Logout';

    my %AgentData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        User  => $Self->{UserLogin},
        Valid => 1
    );

    return if !%AgentData;

    if ( !$AgentData{UserPrintBehaviour} ) {
        $AgentData{UserPrintBehaviour} = 'ask';
    }

    return if $AgentData{UserPrintBehaviour} eq 'standard';

    # get translation
    my $OverlayTitle  = $LayoutObject->{LanguageObject}->Translate("Print");
    my $OverlayHTML   = $LayoutObject->{LanguageObject}->Translate("Please select the type of printout");
    my $PrintStandard = $LayoutObject->{LanguageObject}->Translate("Print Standard");
    my $PrintRichtext = $LayoutObject->{LanguageObject}->Translate("Print Richtext");

    if ( $AgentData{UserPrintBehaviour} eq 'ask' ) {
        my $AppendString = <<"END";
<script type="text/javascript">//<![CDATA[
    function TicketPrintRichtextInit(Element) {
        var OverlayTitle  = '$OverlayTitle',
            OverlayHTML   = '$OverlayHTML...',
            URL           = Element.attr('href'),
            URLRichtext   = URL.replace("Action=AgentTicketPrint", "Action=AgentTicketPrintRichtext");

        OverlayHTML = '<div class="FieldOverlay">' + OverlayHTML + '</div>';

        Core.UI.Dialog.ShowDialog({
            Modal: true,
            Title: OverlayTitle,
            HTML: OverlayHTML,
            PositionTop: \'100px\',
            PositionLeft: \'Center\',
            CloseOnEscape: true,
            Buttons: [
                {
                    Label: '$PrintStandard',
                    Function: function() {
                        Core.UI.Dialog.CloseDialog(\$('.Dialog:visible'));
                        Core.UI.Popup.OpenPopup(URL, 'TicketAction');
                        return false;
                    },
                },
                {
                    Label: '$PrintRichtext',
                    Function: function() {
                        Core.UI.Dialog.CloseDialog(\$('.Dialog:visible'));
                        Core.UI.Popup.OpenPopup(URLRichtext, 'TicketAction');
                        return false;
                    },
                },
            ],
        });

        return false;
    }
//]]></script>
END

        if ( $Param{Data} !~ /function TicketPrintRichtextInit/ ) {
            ${ $Param{Data} } .= $AppendString;
        }

        my $ReplaceString
            = '(<a.*?href=[^>]*?AgentTicketPrint;.*?")(.*?)AsPopup.*?PopupType_TicketAction(.*?</a>)';
        if ( $Param{Data} !~ /return TicketPrintRichtextInit/ ) {
            ${ $Param{Data} }
                =~ s{ $ReplaceString }{$1 onclick="javascript:return TicketPrintRichtextInit(\$(this));"$2$3}gxi;
        }
    }
    elsif ( $AgentData{UserPrintBehaviour} eq 'printrichtext'
        && ${ $Param{Data} } !~ /AgentTicketPrintRichtext/
    ) {
        ${ $Param{Data} } =~ s/AgentTicketPrint;/AgentTicketPrintRichtext;/g;
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
