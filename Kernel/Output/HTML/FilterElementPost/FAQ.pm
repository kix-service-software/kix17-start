# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::FilterElementPost::FAQ;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Web::Request',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check data
    return if !$Param{Data};
    return if ref $Param{Data} ne 'SCALAR';
    return if !${ $Param{Data} };
    return if !$Param{TemplateFile};

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check permission
    return if !$LayoutObject->{EnvRef}->{'UserIsGroupRo[faq]'};

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get allowed template names
    my $ValidTemplates = $ConfigObject->Get('Frontend::Output::FilterElementPost')->{FAQ}->{Templates};

    # check template name
    return if !$ValidTemplates->{ $Param{TemplateFile} };

    # if no session cookies are used we attach the session as URL parameter
    my $SessionString = '';
    if ( !$ConfigObject->Get('SessionUseCookie') ) {
        my $SessionID = $Param{SessionID}
            || $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $ConfigObject->Get('SessionName') )
            || '';
        $SessionString = $ConfigObject->Get('SessionName') . '=' . $SessionID . ';';
    }

    my $StartPattern    = '<!-- [ ] OutputFilterHook_TicketOptionsEnd [ ] --> .+?';
    my $FAQTranslatable = $LayoutObject->{LanguageObject}->Translate('FAQ');

    # add FAQ link to an existing Options block
    #$FinishPattern will be replaced by $Replace
    if ( ${ $Param{Data} } =~ m{ $StartPattern }ixms ) {

        my $FinishPattern = '</div>';
        my $Replace       = <<"END";
                        <a  href=\"#\" id=\"OptionFAQ\">[ $FAQTranslatable ]</a>
                    </div>
END
        ${ $Param{Data} } =~ s{ ($StartPattern) $FinishPattern }{$1$Replace}ixms;

        # inject the necessary JS into the template
        $LayoutObject->AddJSOnDocumentComplete( Code => <<"EOF");
/*global FAQ: true */
FAQ.Agent.TicketCompose.InitFAQTicketCompose(\$('#RichText'));
\$('#OptionFAQ').bind('click', function (event) {
    var FAQIFrame = '<iframe class=\"TextOption FAQ\" src=\"' + Core.Config.Get('CGIHandle') + '?' + '$SessionString' + 'Action=AgentFAQExplorer;Nav=None;Subject=;What=\"></iframe>';
    Core.UI.Dialog.ShowContentDialog(FAQIFrame, '', '10px', 'Center', true);
    return false;
});
EOF

        return 1;
    }

    # add FAQ link and its own block, if there no TicketOptions block was called
    $StartPattern = '<!-- [ ] OutputFilterHook_NoTicketOptionsFallback [ ] --> .+?';
    my $OptionsTranslatable = $LayoutObject->{LanguageObject}->Translate('Options');
    my $Replace             = <<"END";
<!-- OutputFilterHook_NoTicketOptionsFallback -->
                    <label for=\"Options\">$OptionsTranslatable:</label>
                    <div class="Options Field">
                        <a  href=\"#\" id=\"OptionFAQ\">[ $FAQTranslatable ]</a>
                    </div>
                    <div class=\"Clear\"></div>
END
    ${ $Param{Data} } =~ s{ ($StartPattern) }{$Replace}ixms;

    $LayoutObject->AddJSOnDocumentComplete( Code => <<"EOF");
/*global FAQ: true */
FAQ.Agent.TicketCompose.InitFAQTicketCompose(\$('#RichText'));
\$('#OptionFAQ').bind('click', function (event) {
    var FAQIFrame = '<iframe class="TextOption FAQ" src="' + Core.Config.Get('CGIHandle') + '?' + '$SessionString' + 'Action=AgentFAQExplorer;Nav=None;Subject=;What="></iframe>';
    Core.UI.Dialog.ShowContentDialog(FAQIFrame, '', '10px', 'Center', true);
    return false;
});
EOF

    return 1;
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
