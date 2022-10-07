# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::CustomerUser::Generic;

use strict;
use warnings;

use Kernel::System::ObjectManager;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get UserID param
    $Self->{UserID} = $Param{UserID} || die "Got no UserID!";

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check required params
    my @Params = split /;/, $Param{Config}->{Required};
    for my $Key (@Params) {
        return if !$Key;
        return if !$Param{Data}->{$Key};
    }

    # get all attributes
    @Params = split /;/, $Param{Config}->{Attributes};

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # build url
    my $URL = '';
    KEY:
    for my $Key (@Params) {
        next KEY if !$Param{Data}->{$Key};
        if ($URL) {
            $URL .= ', ';
        }
        $URL .= $LayoutObject->LinkEncode( $Param{Data}->{$Key} );
    }
    $URL = $Param{Config}->{URL} . $URL;

    my $IconName = $Param{Config}->{IconName};

    my $HTMLLink = $Kernel::OM->GetNew('Kernel::Output::HTML::Layout')->Output(
        Template => <<'END',
<a class="[% Data.CSSClass %]" [% FOREACH Attribute IN Data.HTMLData %]data-[% Attribute.key | html %]="[% Attribute.value | html %]" [% END %]href="[% Data.URL %]" target="[% Data.Target %]" title="[% Translate(Data.Text) | html %]">
    [% Translate(Data.Text) | html %][% Data.Extension | html %]
</a>
END
        Data     => {
            %{ $Param{Config} },
            URL      => $URL,
            IconName => $IconName,
        },
    );
    my %Safe = $Kernel::OM->Get('Kernel::System::HTMLUtils')->Safety(
        String       => $HTMLLink,
        NoApplet     => 1,
        NoObject     => 1,
        NoEmbed      => 1,
        NoSVG        => 1,
        NoImg        => 1,
        NoIntSrcLoad => 0,
        NoExtSrcLoad => 1,
        NoJavaScript => 1,
    );
    if ( $Safe{Replace} ) {
        $HTMLLink = $Safe{String};
    }

    # generate block
    $LayoutObject->Block(
        Name => 'CustomerItemRow',
        Data => {
            %{ $Param{Config} },
            URL      => $URL,
            IconName => $IconName,
            HTMLLink => $HTMLLink,
        },
    );

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
