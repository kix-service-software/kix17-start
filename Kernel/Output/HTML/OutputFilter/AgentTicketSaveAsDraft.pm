# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilter::AgentTicketSaveAsDraft;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check data
    return if !$Param{Data};
    return if ref $Param{Data} ne 'SCALAR';
    return if !${ $Param{Data} };

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Self->{Config} = $ConfigObject->Get('Ticket::SaveAsDraftAJAXHandler');

    my $Interval          = $Self->{Config}->{Interval};
    my $TranslatedLoadMsg = $LayoutObject->{LanguageObject}->Translate( $Self->{Config}->{LoadMessage} );
    my $Action            = $LayoutObject->{EnvRef}->{Action};
    my $Subaction         = $ParamObject->GetParam( Param => 'Subaction' ) || '';
    my $InitialLoadDraft  = 'true';
    my $SearchPattern;

    # get pretend action from action common tab if set
    if ( $Action eq 'AgentTicketZoomTabActionCommon' ) {
        $SearchPattern = '<input\s.*?name=\"PretendAction\"\svalue=\"(.*?)\".*?\/>';
        if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms ) {
            if ( defined $1 && $1 ) {
                $Action = $1;
                my $OutputFilterConfig = $ConfigObject->Get('Frontend::Output::FilterElementPost');
                return 1 if (
                    !defined $OutputFilterConfig->{AgentTicketSaveAsDraft}->{Templates}->{$Action}
                    || !$OutputFilterConfig->{AgentTicketSaveAsDraft}->{Templates}->{$Action}
                );
            }
        }
    }

    # check if 'Subaction' of request begins with 'Store'
    if ( $Subaction =~ /^(Store|SendEmail)/ ) {
        $InitialLoadDraft = 'false';
    }

    # create HMTL
    $SearchPattern = '<button\s+.*?class=\"(CallForAction\sPrimary|Primary\sCallForAction)\"\s+.*?type=\"submit(RichText)?\"\s+.*?>(.*?)<\/button>';

    my $ReplacementString = '<button id="SaveAsDraft" class="CallForAction SaveAsDraftButton" type="button" value="SaveAsDraft"><span><i class="fa fa-file-text"></i>'
                          . $LayoutObject->{LanguageObject}->Translate('Save As Draft (Subject and Text)')
                          . '</span></button>';

    # get config values
    my $LoadMessage   = $LayoutObject->{LanguageObject}->Translate('Load');
    my $DeleteMessage = $LayoutObject->{LanguageObject}->Translate('Delete');
    my $Question      = $LayoutObject->{LanguageObject}->Translate('Question');
    my $Attributes    = join( ',', @{ $Self->{Config}->{Attributes} } );

    $LayoutObject->AddJSOnDocumentComplete( Code => <<"EOF");
        Core.Config.AddConfig({
            Load:         '$LoadMessage',
            Delete:       '$DeleteMessage',
            Question:     '$Question',
            LoadDraftMsg: '$TranslatedLoadMsg',
            Attributes:   '$Attributes'
        });
        Core.KIX4OTRS.InitSaveAsDraft('$Action','$TranslatedLoadMsg','$Interval', '$InitialLoadDraft');
EOF

    if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms ) {
        ${ $Param{Data} } =~ s{ ($SearchPattern) }{ $1$ReplacementString }ixms;
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
