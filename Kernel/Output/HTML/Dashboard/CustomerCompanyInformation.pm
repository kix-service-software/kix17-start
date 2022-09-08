# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Dashboard::CustomerCompanyInformation;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed parameters
    for my $Needed (qw(Config Name UserID)) {
        die "Got no $Needed!" if ( !$Self->{$Needed} );
    }

    $Self->{PrefKey} = 'UserDashboardPref' . $Self->{Name} . '-Shown';

    $Self->{CacheKey} = $Self->{Name};

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    return;
}

sub Config {
    my ( $Self, %Param ) = @_;

    return (
        %{ $Self->{Config} },

        # caching not needed
        CacheKey => undef,
        CacheTTL => undef,
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    return if !$Param{CustomerID};

    my %CustomerCompany = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
        CustomerID => $Param{CustomerID},
    );

    my $CustomerCompanyConfig = $Kernel::OM->Get('Kernel::Config')->Get( $CustomerCompany{Source} || '' );
    return if ref $CustomerCompanyConfig ne 'HASH';
    return if ref $CustomerCompanyConfig->{Map} ne 'ARRAY';

    return if !%CustomerCompany;

    # get needed objects
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $ValidObject     = $Kernel::OM->Get('Kernel::System::Valid');
    my $CompanyIsValid;

    # make ValidID readable
    if ( $CustomerCompany{ValidID} ) {
        my @ValidIDs = $ValidObject->ValidIDsGet();
        $CompanyIsValid = grep { $CustomerCompany{ValidID} == $_ } @ValidIDs;

        $CustomerCompany{ValidID} = $ValidObject->ValidLookup(
            ValidID => $CustomerCompany{ValidID},
        );

        $CustomerCompany{ValidID} = $LayoutObject->{LanguageObject}->Translate( $CustomerCompany{ValidID} );
    }

    ENTRY:
    for my $Entry ( @{ $CustomerCompanyConfig->{Map} } ) {
        my $Key = $Entry->[0];

        # do not show items if they're not marked as visible
        next ENTRY if !$Entry->[3];

        # do not show empty entries
        next ENTRY if !length( $CustomerCompany{$Key} );

        $LayoutObject->Block( Name => "ContentSmallCustomerCompanyInformationRow" );

        if ( $Key eq 'CustomerID' ) {
            $LayoutObject->Block(
                Name => "ContentSmallCustomerCompanyInformationRowLink",
                Data => {
                    %CustomerCompany,
                    Label => $Entry->[1],
                    Value => $CustomerCompany{$Key},
                    URL =>
                        '[% Env("Baselink") %]Action=AdminCustomerCompany;Subaction=Change;CustomerID=[% Data.CustomerID | uri %];Nav=Agent',
                    Target => '',
                },
            );

            next ENTRY;
        }

        # check if a link must be placed
        if ( $Entry->[6] ) {
            my $Link = $Kernel::OM->GetNew('Kernel::Output::HTML::Layout')->Output(
                Template => '<a href="[% Data.URL | Interpolate %]" target="[% Data.Target | html %]">[% Data.Value | html %]</a>',
                Data     => {
                    %CustomerCompany,
                    Label  => $Entry->[1],
                    Value  => $CustomerCompany{$Key},
                    URL    => $Entry->[6],
                    Target => '_blank',
                },
            );
            my %Safe = $HTMLUtilsObject->Safety(
                String       => $Link,
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
                $Link = $Safe{String};
            }
            $LayoutObject->Block(
                Name => "ContentSmallCustomerCompanyInformationRowLink",
                Data => {
                    Label => $Entry->[1],
                    Link  => $Link,
                },
            );

            next ENTRY;

        }

        $LayoutObject->Block(
            Name => "ContentSmallCustomerCompanyInformationRowText",
            Data => {
                %CustomerCompany,
                Label => $Entry->[1],
                Value => $CustomerCompany{$Key},
            },
        );

        if ( $Key eq 'CustomerCompanyName' && defined $CompanyIsValid && !$CompanyIsValid ) {
            $LayoutObject->Block(
                Name => 'ContentSmallCustomerCompanyInvalid',
            );
        }
    }

    my $Content = $LayoutObject->Output(
        TemplateFile => 'AgentDashboardCustomerCompanyInformation',
        Data         => {
            %{ $Self->{Config} },
            Name => $Self->{Name},
            %CustomerCompany,
        },
        KeepScriptTags => $Param{AJAX},
    );

    return $Content;
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
