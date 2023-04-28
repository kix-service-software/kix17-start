# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::CustomerTicketTemplates;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    $Self->{ConfigObject}              = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}              = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{LogObject}                 = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{CustomerPortalGroupObject} = $Kernel::OM->Get('Kernel::System::CustomerPortalGroup');
    $Self->{MainObject}                = $Kernel::OM->Get('Kernel::System::Main');
    $Self->{TicketObject}              = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{ParamObject}               = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Self->{Config} = $Self->{ConfigObject}->Get('Ticket::Frontend::CustomerTicketTemplates');

    # load all template backend modules
    my $BackendDir = '/Kernel/Output/HTML/CustomerTicketTemplates';
    for my $INCDir ( reverse @INC ) {
        my $Dir = $INCDir;
        $Dir =~ s'\s'\\s'g;
        my $FullBackendDir = "$Dir$BackendDir";
        if ( -e "$FullBackendDir" ) {
            my @BackendFiles = $Self->{MainObject}->DirectoryRead(
                Directory => $FullBackendDir,
                Filter    => '*.pm',
            );
            for my $Backend (@BackendFiles) {
                $Backend =~ s{\A.*\/(.+?).pm\z}{$1}xms;
                $Self->{BackendObjects}->{$Backend} = $Kernel::OM->Get("Kernel::Output::HTML::CustomerTicketTemplates::$Backend");
            }
        }
    }

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get portal groups
    my %PortalGroups = $Self->{CustomerPortalGroupObject}->PortalGroupList(
        ValidID => 1,
    );

    # get all ticket templates
    my %TemplateList;
    foreach my $BackendObject (keys %{$Self->{BackendObjects}}) {
        my %BackendTemplateList = $Self->{BackendObjects}->{$BackendObject}->TicketTemplateList(
            UserID => $Self->{UserID},
        );
        foreach my $TemplateID (keys %BackendTemplateList) {
            # only active groups
            next if !$PortalGroups{$BackendTemplateList{$TemplateID}->{PortalGroupID}};

            $TemplateList{$BackendTemplateList{$TemplateID}->{PortalGroupID}}->{$BackendObject.'::'.$BackendTemplateList{$TemplateID}->{Name}} = $BackendTemplateList{$TemplateID};
        }
    }

    # filter ticket templates
    if (
        IsHashRefWithData($Self->{Config}->{UserAttributeWhitelist})
        || IsHashRefWithData($Self->{Config}->{UserAttributeBlacklist})
    ) {
        foreach my $PortalGroupID ( sort keys %TemplateList ) {
            TEMPLATE:
            foreach my $TemplateKey ( sort keys %{$TemplateList{$PortalGroupID}}) {
                my $UseTemplate  = 1;
                my $AttributeKey = $TemplateList{$PortalGroupID}->{$TemplateKey}->{Name};

                # process configured attributes to check blacklist
                if ( IsHashRefWithData($Self->{Config}->{UserAttributeBlacklist}) ) {
                    # check blacklist
                    RESTRICTION:
                    for my $UserAttributeKey ( sort keys %{ $Self->{Config}->{UserAttributeBlacklist} } ) {
                        next RESTRICTION if ( $UserAttributeKey !~ /^(?:\Q$AttributeKey\E)\:\:(.*)/ );
                        my $UserAttribute = $1;

                        if (
                            !$Self->{$UserAttribute}
                            || $Self->{$UserAttribute} =~ /$Self->{Config}->{UserAttributeBlacklist}->{$UserAttributeKey}/sm
                        ) {
                            $UseTemplate = 0;
                            last RESTRICTION;
                        }
                    }
                }

                # process configured attributes to check whitelist
                if (
                    $UseTemplate
                    && IsHashRefWithData($Self->{Config}->{UserAttributeWhitelist})
                ) {
                    # check whitelist
                    RESTRICTION:
                    for my $UserAttributeKey ( sort keys %{ $Self->{Config}->{UserAttributeWhitelist} } ) {
                        next RESTRICTION if ( $UserAttributeKey !~ /^(?:\Q$AttributeKey\E)\:\:(.*)/ );
                        my $UserAttribute  = $1;

                        if (
                            $Self->{$UserAttribute}
                            && $Self->{$UserAttribute} =~ /$Self->{Config}->{UserAttributeWhitelist}->{$UserAttributeKey}/sm
                        ) {
                            $UseTemplate = 1;
                            last RESTRICTION;
                        }
                        else {
                            $UseTemplate = 0;
                        }
                    }
                }

                if (!$UseTemplate) {
                    delete $TemplateList{$PortalGroupID}->{$TemplateKey};
                }
            }

            # remove whole portal group if no templates are available for this one
            if (!IsHashRefWithData($TemplateList{$PortalGroupID})) {
                delete $TemplateList{$PortalGroupID};
            }
        }
    }

    # create group selectors
    foreach my $PortalGroupID (sort { $PortalGroups{$a} cmp $PortalGroups{$b} } keys %PortalGroups) {
        # only groups with templates
        next if !$TemplateList{$PortalGroupID};

        my %PortalGroup = $Self->{CustomerPortalGroupObject}->PortalGroupGet(
            PortalGroupID => $PortalGroupID,
        );

        # save details for later
        $PortalGroups{$PortalGroupID} = \%PortalGroup;

        $Self->{LayoutObject}->Block(
            Name => 'PortalGroupSelector',
            Data => {
                %PortalGroup,
                %{$PortalGroup{Icon}},
            }
        );
    }

    # create portal groups
    foreach my $PortalGroupID (sort { $PortalGroups{$a}->{Name} cmp $PortalGroups{$b}->{Name} } keys %TemplateList) {

        $Self->{LayoutObject}->Block(
            Name => 'PortalGroup',
            Data => $PortalGroups{$PortalGroupID},
        );

        foreach my $TemplateKey (sort { $TemplateList{$PortalGroupID}->{$a}->{Name} cmp $TemplateList{$PortalGroupID}->{$b}->{Name} } keys %{$TemplateList{$PortalGroupID}}) {
            $Self->{LayoutObject}->Block(
                Name => 'TicketTemplate',
                Data => {
                    %{$TemplateList{$PortalGroupID}->{$TemplateKey}},
                    %{$PortalGroups{$PortalGroupID}->{Icon}},
                },
            );
        }
    }

    my $Output = $Self->{LayoutObject}->CustomerHeader(
        Title   => $Self->{Subaction},
    );
    $Output .= $Self->{LayoutObject}->CustomerNavigationBar();
    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'CustomerTicketTemplates',
        Data         => \%Param,
    );
    $Output .= $Self->{LayoutObject}->CustomerFooter();

    # return page
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
