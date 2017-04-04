# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
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
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $Self->{Config} = $ConfigObject->Get('Ticket::SaveAsDraftAJAXHandler');

    my $Interval = $Self->{Config}->{Interval};
    my $TranslatedLoadMsg
        = $LayoutObject->{LanguageObject}->Translate( $Self->{Config}->{LoadMessage} );
    my $Action = $LayoutObject->{EnvRef}->{Action};
    my $SearchPattern;

    # get pretend action from action common tab if set
    if ( $Action eq 'AgentTicketZoomTabActionCommon' ) {
        $SearchPattern = '<input\s.*?name=\"PretendAction\"\svalue=\"(.*?)\".*?\/>';
        if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms )
        {
            if ( defined $1 && $1 ) {
                $Action = $1;
                my $OutputFilterConfig
                    = $ConfigObject->Get('Frontend::Output::FilterElementPost');
                return
                    if !
                        defined $OutputFilterConfig->{AgentTicketSaveAsDraft}->{Templates}
                        ->{$Action}
                        || !(
                            $OutputFilterConfig->{AgentTicketSaveAsDraft}->{Templates}->{$Action}
                        );
            }
        }
    }

    # create HMTL
    $SearchPattern
        = '<button\s+.*?class=\"(CallForAction\sPrimary|Primary\sCallForAction)\"\s+.*?type=\"submit(RichText)?\"\s+.*?>(.*?)<\/button>';

    my $ReplacementString
        = '<button id="SaveAsDraft" class="CallForAction SaveAsDraftButton" type="button" value="SaveAsDraft"><span><i class="fa fa-file-text"></i>'
        . $LayoutObject->{LanguageObject}->Translate('Save As Draft (Subject and Text)')
        . '</span></button>';

    # get config values
    my $YesMessage    = $LayoutObject->{LanguageObject}->Translate('Yes');
    my $DeleteMessage = $LayoutObject->{LanguageObject}->Translate('Delete');
    my $Question      = $LayoutObject->{LanguageObject}->Translate('Question');
    my $Attributes    = join( ',', @{ $Self->{Config}->{Attributes} } );

    $LayoutObject->AddJSOnDocumentComplete( Code => <<"EOF");
        Core.Config.AddConfig({
            Yes: '$YesMessage',
            Delete: '$DeleteMessage',
            Question: '$Question',
            LoadDraftMsg: '$TranslatedLoadMsg',
            Attributes: '$Attributes'
        });
        Core.KIX4OTRS.InitSaveAsDraft('$Action','$TranslatedLoadMsg','$Interval');
EOF

    if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms )
    {
        ${ $Param{Data} } =~ s{ ($SearchPattern) }{ $1$ReplacementString }ixms;
    }

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
