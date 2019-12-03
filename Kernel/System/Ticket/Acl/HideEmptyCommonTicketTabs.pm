# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Acl::HideEmptyCommonTicketTabs;

use strict;
use warnings;

use Kernel::System::ObjectManager;

our @ObjectDependencies = (
    'Kernel::Config',
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

    if (
        defined $Param{Action}
        && $Param{Action} eq 'AgentTicketZoom'
        )
    {
        # check needed stuff
        for (qw(Data)) {
            if ( !$Param{$_} ) {
                return 1;
            }
        }
        if ( ref( $Param{'Data'} ) ne 'HASH' ) {
            return 1;
        }

        # get needed objects
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

        # get registered tabs
        my $ConfigRef = $ConfigObject->Get('AgentTicketZoomBackend');

        # check config
        if ( ref( $ConfigRef ) eq 'HASH' ) {
            # process data
            my @Blacklist;
            ACTION:
            for my $Key ( keys( %{ $Param{'Data'} } ) ) {

                # skip if it is not a tab
                next ACTION if ( $Param{'Data'}->{$Key} !~ m/^AgentTicketZoom###(.+)$/ );

                # get tab action
                my $TabAction = $1;

                # skip if it is an unknown tab or relevant data is missing
                next ACTION if (
                    !$ConfigRef->{ $TabAction }
                    || !$ConfigRef->{ $TabAction }->{'Link'}
                    || $ConfigRef->{ $TabAction }->{'Link'} !~ /Action=AgentTicketZoomTabActionCommon;/
                    || $ConfigRef->{ $TabAction }->{'Link'} !~ /PretendAction=(.+?);/
                );

                # get pretend action
                my $PretendAction = $1;

                # get config for pretend action
                my $PretendConfig = $ConfigObject->Get( 'Ticket::Frontend::' . $PretendAction );

                # process pretend action config
                next if ( ref($PretendConfig) ne 'HASH' );

                # check scalar config
                for my $Attribute (
                    qw(
                    Queue TicketType Service Owner Responsible State Note Priority Title
                    )
                    )
                {
                    next ACTION if ( $PretendConfig->{$Attribute} );
                }

                # check hash config
                for my $Attribute (qw(DynamicField)) {
                    next ACTION
                        if (
                        defined $PretendConfig->{$Attribute}
                        && ref( $PretendConfig->{$Attribute} ) ne 'HASH'
                        );
                }

                my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

                # check dynamic field config
                for my $DynamicField ( keys( %{ $PretendConfig->{'DynamicField'} } ) ) {

                    # check if dynamic field is valid
                    my $Valid = 1;
                    if ( $PretendConfig->{'DynamicField'}->{$DynamicField} ) {

                        # get data of dynamic field
                        my $DynamicFieldObject = $DynamicFieldObject->DynamicFieldGet(
                            Name => $DynamicField,
                        );

                        # check if its a hash with data
                        if (
                            ref($DynamicFieldObject) ne 'HASH'
                            || !keys( %{$DynamicFieldObject} )
                            )
                        {
                            $Valid = 0;
                        }

                        # check if the field is valid
                        if ( $DynamicFieldObject->{ValidID} != 1 ) {
                            $Valid = 0;
                        }
                    }

                    next ACTION if ( $PretendConfig->{'DynamicField'}->{$DynamicField} && $Valid );
                }

                # add action to blacklist
                push( @Blacklist, $Param{'Data'}->{$Key} );
            }

            # add acl rule
            $Param{Acl}->{'996_HideEmptyCommonTicketTabs'} = {
                PossibleNot => {
                    Action => \@Blacklist,
                },
            };
        }
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
