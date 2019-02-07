# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilter::ToolbarSearchProfile;

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

    # check if searchprofile dropdown exists and add form id
    my $SearchPattern
        = '(<form(.*?)method\=\"post\"\sname\=\"SearchProfile\")(>)';
    my $ReplacementString = ' id="SearchProfileForm"';

    if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms )
    {
        ${ $Param{Data} } =~ s{ $SearchPattern }{ $1$ReplacementString$3 }ixms;
    }
    else {
        # dropdown is deactivated
        return 1;
    }

    # replace action
    $SearchPattern
        = '(value=\")AgentTicketSearch(\"\/>)(.*)';
    $ReplacementString
        = '<input type="hidden" name="Profile" value=""/><input type="hidden" name="ClassID" value=""/>';

    if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms )
    {
        ${ $Param{Data} }
            =~ s{ $SearchPattern }{ $1ToolbarSearchProfileAJAXHandler$2$ReplacementString$3 }ixms;
    }

    # create javascript for bind
    my $ReplaceString = '[% WRAPPER JSOnDocumentComplete %]'
        . '<script type="text/javascript">//<![CDATA['
        . '$(\'#ToolBarSearchProfiles\').bind(\'change\', function (Event) {'
        . '    var Data = Core.AJAX.SerializeForm($(\'#SearchProfileForm\'));'
        . '    if ( $(this).val() != null ) {'
        . '        Core.AJAX.FunctionCall(Core.Config.Get(\'CGIHandle\'), Data, function (Result) {'
        . '            $(\'input[name="Action"]\').val(Result.Action);'
        . '            $(\'input[name="Subaction"]\').val(Result.Subaction);'
        . '            $(\'input[name="Profile"]\').val(Result.Profile);'
        . '            $(\'input[name="ClassID"]\').val(Result.ClassID);'
        . '            $(Event.target).closest(\'form\').submit();'
        . '        },\'json\',\'Async\');'
        . '    }'
        . '    Event.preventDefault();'
        . '    Event.stopPropagation();'
        . '    return false;'
        . '});'
        . '//]]></script>'
        . '[% END %]';

    # append replace string
    ${ $Param{Data} } .= $ReplaceString;

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
