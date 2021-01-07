# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilter::AdminTemplateX;

use strict;
use warnings;

use Kernel::System::EmailParser;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::DB',
    'Kernel::System::EmailParser',
    'Kernel::System::HTMLUtils',
    'Kernel::System::StandardTemplate',
    'Kernel::System::State',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self if ( !$Param{UserType} || $Param{UserType} eq 'Customer' );

    $Self->{LayoutObject}           = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{DBObject}               = $Kernel::OM->Get('Kernel::System::DB');
    $Self->{ParserObject}           = Kernel::System::EmailParser->new(
        Mode         => 'Standalone',
    );
    $Self->{HTMLUtilsObject}        = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    $Self->{StandardTemplateObject} = $Kernel::OM->Get('Kernel::System::StandardTemplate');
    $Self->{StateObject}            = $Kernel::OM->Get('Kernel::System::State');
    $Self->{ParamObject}            = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return if !$Param{Data};
    return if ref $Param{Data} ne 'SCALAR';
    return if !${ $Param{Data} };

    # get params as string
    my %GetParam;
    for (qw(Subaction Name To Cc Bcc)) {
        $GetParam{$_} = $Self->{ParamObject}->GetParam( Param => $_ ) || '';
    }

    # get params at integer
    for (qw(ID StateID PendingTime PendingType)) {
        $GetParam{$_} = $Self->{ParamObject}->GetParam( Param => $_ ) || '';
        $GetParam{$_} =~ s/[^0-9]+//g;
        if ( $GetParam{$_} =~ m/^$/ ) {
            $GetParam{$_} = undef;
        }
    }

    if (
        $GetParam{Subaction}
        && $GetParam{Subaction} =~ m/(Add|Change)Action$/
    ) {
        if (
            !$GetParam{ID}
            && $GetParam{Name}
        ) {
            $GetParam{ID} = $Self->{StandardTemplateObject}->StandardTemplateLookup(
                StandardTemplate => $GetParam{Name},
            );
        }

        if (
            $GetParam{ID}
        ) {
            # prepare params
            for (qw(To Cc Bcc)) {
                my @Addresses = $Self->{ParserObject}->SplitAddressLine(
                    Line => $GetParam{$_},
                );
                $GetParam{$_} = join( ",", @Addresses );
            }

            my $QueryCondition = $Self->{DBObject}->QueryCondition(
                Key           => 'template_id',
                Value         => $GetParam{ID},
                SearchPrefix  => '',
                SearchSuffix  => '',
                CaseSensitive => 1,
            );

            my $SQL = 'SELECT template_id'
                . ' FROM standard_templatex'
                . ' WHERE ' . $QueryCondition;

            my $Success = $Self->{DBObject}->Prepare(
                SQL   => $SQL,
                Limit => 1,
            );
            if ($Success) {
                my $Check = "";
                while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
                    $Check = $Row[0];
                    last;
                }
                return
                    if (
                    !$Check
                    && !$GetParam{To}
                    && !$GetParam{Cc}
                    && !$GetParam{Bcc}
                    && !$GetParam{StateID}
                    && !$GetParam{PendingTime}
                    );

                # update value
                if (
                    !$GetParam{To}
                    && !$GetParam{Cc}
                    && !$GetParam{Bcc}
                    && !$GetParam{StateID}
                    && !$GetParam{PendingTime}
                ) {
                    $Self->{DBObject}->Do(
                        SQL => 'DELETE'
                            . ' FROM standard_templatex'
                            . ' WHERE ' . $QueryCondition,
                    );
                }
                elsif ( !$Check ) {
                    $Self->{DBObject}->Do(
                        SQL => 'INSERT INTO standard_templatex'
                            . ' (template_id, t_to, t_cc, t_bcc, t_ticket_state_id, t_pending_time, t_pending_type)'
                            . ' VALUES (?, ?, ?, ?, ?, ?, ?)',
                        Bind => [
                            \$GetParam{ID}, \$GetParam{To}, \$GetParam{Cc}, \$GetParam{Bcc},
                            \$GetParam{StateID}, \$GetParam{PendingTime}, \$GetParam{PendingType},
                        ],
                    );
                }
                else {
                    $Self->{DBObject}->Do(
                        SQL => 'UPDATE standard_templatex'
                            . ' SET t_to=?, t_cc=?, t_bcc=?, t_ticket_state_id=?, t_pending_time=?, t_pending_type=?'
                            . ' WHERE ' . $QueryCondition,
                        Bind => [
                            \$GetParam{To}, \$GetParam{Cc}, \$GetParam{Bcc}, \$GetParam{StateID},
                            \$GetParam{PendingTime}, \$GetParam{PendingType},
                        ],
                    );
                }
            }
        }
    }

    my $FieldMatch = '(?s)(<fieldset[^>]+>.*?<label[^>]+>.*?<label[^>]+>.*?)(<label[^>]+>)';
    if ( ${ $Param{Data} } =~ m/$FieldMatch/ ) {
        my $FieldBefore = $1;
        my $FieldAfter  = $2;

        my $TemplateTo          = "";
        my $TemplateCc          = "";
        my $TemplateBcc         = "";
        my $TemplateStateID     = "";
        my $TemplatePendingTime = "";
        my $TemplatePendingType = "";
        if ( $GetParam{ID} ) {

            my $QueryCondition = $Self->{DBObject}->QueryCondition(
                Key           => 'template_id',
                Value         => $GetParam{ID},
                SearchPrefix  => '',
                SearchSuffix  => '',
                CaseSensitive => 1,
            );

            my $SQL = 'SELECT t_to, t_cc, t_bcc, t_ticket_state_id, t_pending_time, t_pending_type'
                . ' FROM standard_templatex'
                . ' WHERE ' . $QueryCondition;

            my $Success = $Self->{DBObject}->Prepare(
                SQL   => $SQL,
                Limit => 1,
            );
            if ( !$Success ) {
                return;
            }

            while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
                $TemplateTo  = $Self->{HTMLUtilsObject}->ToHTML( String => ( $Row[0] || '' ) );
                $TemplateCc  = $Self->{HTMLUtilsObject}->ToHTML( String => ( $Row[1] || '' ) );
                $TemplateBcc = $Self->{HTMLUtilsObject}->ToHTML( String => ( $Row[2] || '' ) );
                $TemplateStateID = ( $Row[3] || '' );
                $TemplatePendingTime
                    = $Self->{HTMLUtilsObject}->ToHTML( String => ( $Row[4] || '' ) );
                $TemplatePendingType = ( $Row[5] || '' );
                last;
            }
        }

        my $TextTo      = $Self->{LayoutObject}->{LanguageObject}->Get('To');
        my $TextCc      = $Self->{LayoutObject}->{LanguageObject}->Get('Cc');
        my $TextBcc     = $Self->{LayoutObject}->{LanguageObject}->Get('Bcc');
        my $TextStateID = $Self->{LayoutObject}->{LanguageObject}->Get('State');
        my $TextPending = $Self->{LayoutObject}->{LanguageObject}->Get('Pending date');

        my $TextFieldExplanation
            = $Self->{HTMLUtilsObject}->ToHTML(
            String => $Self->{LayoutObject}->{LanguageObject}
                ->Get('Only works for type Answer and Forward')
            );

        my $StateIDStrg = $Self->{LayoutObject}->BuildSelection(
            Data => {
                $Self->{StateObject}->StateList(
                    UserID => 1,
                    Action => $Self->{Action},
                ),
            },
            Name         => 'StateID',
            Size         => 1,
            Multiple     => 0,
            PossibleNone => 1,
            SelectedID   => $TemplateStateID,
        );
        my $PendingTypeStrg = $Self->{LayoutObject}->BuildSelection(
            Data => [
                {
                    Key   => 60,
                    Value => 'minute(s)',
                },
                {
                    Key   => 3600,
                    Value => 'hour(s)',
                },
                {
                    Key   => 86400,
                    Value => 'day(s)',
                },
                {
                    Key   => 2592000,
                    Value => 'month(s)',
                },
                {
                    Key   => 31536000,
                    Value => 'year(s)',
                },

            ],
            Name        => 'PendingType',
            Size        => 1,
            Multiple    => 0,
            SelectedID  => $TemplatePendingType,
            Translation => 1,
            Title       => $Self->{LayoutObject}->{LanguageObject}->Get('Time unit'),
        );
        my $FieldReplace = "$FieldBefore\n"
            . "\n"
            . "<label for=\"To\" >\n"
            . "    $TextTo:\n"
            . "</label>\n"
            . "<div class=\"Field\">\n"
            . "    <input id=\"To\" type=\"text\" name=\"To\" value=\"$TemplateTo\" class=\"W50pc\" />\n"
            . "    <p class=\"FieldExplanation\">$TextFieldExplanation</p>\n"
            . "</div>\n"
            . "<div class=\"Clear\"></div>\n"
            . "<label for=\"Cc\" >\n"
            . "    $TextCc:\n"
            . "</label>\n"
            . "<div class=\"Field\">\n"
            . "    <input id=\"Cc\" type=\"text\" name=\"Cc\" value=\"$TemplateCc\" class=\"W50pc\" />\n"
            . "    <p class=\"FieldExplanation\">$TextFieldExplanation</p>\n"
            . "</div>\n"
            . "<div class=\"Clear\"></div>\n"
            . "<label for=\"Bcc\" >\n"
            . "    $TextBcc:\n"
            . "</label>\n"
            . "<div class=\"Field\">\n"
            . "    <input id=\"Bcc\" type=\"text\" name=\"Bcc\" value=\"$TemplateBcc\" class=\"W50pc\" />\n"
            . "    <p class=\"FieldExplanation\">$TextFieldExplanation</p>\n"
            . "</div>\n"
            . "<div class=\"Clear\"></div>\n"
            . "<label for=\"StateID\" >\n"
            . "    $TextStateID:\n"
            . "</label>\n"
            . "<div class=\"Field\">\n"
            . "    $StateIDStrg\n"
            . "    <p class=\"FieldExplanation\">$TextFieldExplanation</p>\n"
            . "</div>\n"
            . "<div class=\"Clear\"></div>\n"
            . "<label for=\"PendingTime\">$TextPending:</label>\n"
            . "<div class=\"Field\">\n"
            . "    <input type=\"text\" name=\"PendingTime\" id=\"PendingTime\" value=\"$TemplatePendingTime\" class=\"W10pc\"/>\n"
            . "    $PendingTypeStrg\n"
            . "    <p class=\"FieldExplanation\">$TextFieldExplanation</p>\n"
            . "</div>\n"
            . "<div class=\"Clear\"></div>\n"
            . "\n"
            . "$FieldAfter";
        ${ $Param{Data} } =~ s/$FieldMatch/$FieldReplace/g;
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
