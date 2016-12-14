# --
# Kernel/Output/HTML/OutputFilterAdminTemplateX.pm - Output filter
#
# Copyright (C) 2006-2015 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilterAgentTemplateX;

use strict;
use warnings;

use Kernel::System::EmailParser;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::DB',
    'Kernel::System::EmailParser',
    'Kernel::System::StandardTemplate',
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
    $Self->{StandardTemplateObject} = $Kernel::OM->Get('Kernel::System::StandardTemplate');
    $Self->{ParamObject}            = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get param to check
    my $CheckParam = "";
    my $StateFieldID = "";
    if ($Param{TemplateFile} eq 'AgentTicketCompose') {
        $CheckParam = "ResponseID";
        $StateFieldID = "StateID";
    } elsif ($Param{TemplateFile} eq 'AgentTicketForward') {
        $CheckParam = "ForwardTemplateID";
        $StateFieldID = "ComposeStateID";
    } elsif ($Param{TemplateFile} eq 'AgentTicketPhone') {
        $CheckParam = "ForwardTemplateID";
        $StateFieldID = "NextStateID";
    }
    return if !$CheckParam;

    # get TemplateID
    my $TemplateID = $Self->{ParamObject}->GetParam( Param => $CheckParam );
    return if !$TemplateID;

    my $TemplateTo  = "";
    my $TemplateCc  = "";
    my $TemplateBcc = "";

    my $QueryCondition = $Self->{DBObject}->QueryCondition(
        Key           => 'template_id',
        Value         => $TemplateID,
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

    my $JSAdd = "";

    my %Recipients = ();
    my $StateID = "";
    my $PendingTime = "";
    while (my @Row = $Self->{DBObject}->FetchrowArray()) {
        $Recipients{ToCustomer}  = $Row[0];
        $Recipients{CcCustomer}  = $Row[1];
        $Recipients{BccCustomer} = $Row[2];
        $StateID                 = $Row[3];
        $PendingTime             = ($Row[4] || 0) * ($Row[5] || 0);
        last;
    }

    my $AddressesAdd = "";
    TYPE:
    for my $Type (qw(ToCustomer CcCustomer BccCustomer)) {
        next TYPE if !$Recipients{$Type};

        my @Addresses = $Self->{ParserObject}->SplitAddressLine(
            Line => $Recipients{$Type},
        );

        ADDRESS:
        for my $Address (@Addresses) {
            next ADDRESS if !$Address;

            $Address =~ s/"/\\\"/g;
            $AddressesAdd .= "Core.Agent.CustomerSearch.AddTicketCustomer( '$Type', \"$Address\" );\n";
        }
    }

    if ($AddressesAdd) {
        $Self->{LayoutObject}->AddJSOnDocumentComplete(
            Code => $AddressesAdd,
        );
    }

    if ($StateID) {
        $Self->{LayoutObject}->AddJSOnDocumentComplete(
            Code =>   "\$('#$StateFieldID option').each(function() {\n"
                    . "    if (\$(this).val() == '$StateID') {\n"
                    . "        \$('#$StateFieldID').val('$StateID');\n"
                    . "        \$('#$StateFieldID').trigger('change');\n"
                    . "    }\n"
                    . "});",
        );
    }

    if ($PendingTime) {
        # Convert to milliseconds;
        $PendingTime *= 1000;
        $Self->{LayoutObject}->AddJSOnDocumentComplete(
            Code =>   "if (document.getElementById('Year')) {\n"
                    . "    var PendingDate = new Date();\n"
                    . "    PendingDate.setTime(PendingDate.getTime() + $PendingTime);\n"
                    . "    document.getElementById('Year').value = PendingDate.getFullYear();\n"
                    . "    document.getElementById('Month').value = PendingDate.getMonth() + 1;\n"
                    . "    document.getElementById('Day').value = PendingDate.getDate();\n"
                    . "    document.getElementById('Hour').value = PendingDate.getHours();\n"
                    . "    document.getElementById('Minute').value = PendingDate.getMinutes();\n"
                    . "}",
        );
    }

    return 1;
}

1;
