# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminCustomerPortalGroup;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject}               = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}               = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{CustomerPortalGroupObject}  = $Kernel::OM->Get('Kernel::System::CustomerPortalGroup');
    $Self->{LogObject}                  = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ParamObject}                = $Kernel::OM->Get('Kernel::System::Web::Request');
    $Self->{ValidObject}                = $Kernel::OM->Get('Kernel::System::Valid');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my %GetParam = ();
    $GetParam{Search}  = $Self->{ParamObject}->GetParam( Param => 'Search' ) || '*';

    # ------------------------------------------------------------
    # delete
    # ------------------------------------------------------------
    if ( $Self->{Subaction} eq 'Delete' ) {
        my @SelectedIDs = $Self->{ParamObject}->GetArray( Param => 'PortalGroupID' );

        if (@SelectedIDs) {
            my $Result = $Self->{CustomerPortalGroupObject}->PortalGroupDelete(
                PortalGroupIDs => \@SelectedIDs,
            );
        }

        $Self->_Overview(
            Search => $GetParam{Search},
        );

        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();

        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminCustomerPortalGroup',
            Data         => \%Param,
        );
        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # add / edit
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Add' || $Self->{Subaction} eq 'Edit' ) {

        $GetParam{PortalGroupID} = $Self->{ParamObject}->GetParam( Param => 'PortalGroupID' ) || '';

        $Self->_AddEdit(
            %Param,
            %GetParam,
        );

        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();

        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminCustomerPortalGroup',
            Data         => \%Param,
        );
        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # save
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Save' ) {

        # challenge token check for write action
        $Self->{LayoutObject}->ChallengeTokenCheck();

        # get params
        for (qw(PortalGroupID Name ValidID)) {
            $GetParam{$_} = $Self->{ParamObject}->GetParam( Param => $_ ) || '';
        }

        my %Error;

        if ( !$GetParam{Name} ) {
            $Error{'NameInvalid'} = 'ServerError';
        }

        if ( !%Error ) {

            my %UploadStuff = $Self->{ParamObject}->GetUploadAll(
                Param  => 'FileUpload',
            );

            # save to database
            if ( !$GetParam{PortalGroupID} ) {
                $GetParam{PortalGroupID} = $Self->{CustomerPortalGroupObject}->PortalGroupAdd(
                    %GetParam,
                    Icon   => \%UploadStuff,
                    UserID => $Self->{UserID},
                );
                if ( !$GetParam{DashboardID} ) {
                    $Error{Message} = $Self->{LogObject}->GetLogEntry(
                        Type => 'Error',
                        What => 'Message',
                    );
                }
            }
            else {
                my $Success = $Self->{CustomerPortalGroupObject}->PortalGroupUpdate(
                    %GetParam,
                    Icon   => \%UploadStuff,
                    UserID => $Self->{UserID},
                );
                if ( !$Success ) {
                    $Error{Message} = $Self->{LogObject}->GetLogEntry(
                        Type => 'Error',
                        What => 'Message',
                    );
                }
            }

            if ( !%Error ) {

                # redirect to overview
                return $Self->{LayoutObject}->Redirect( OP => "Action=$Self->{Action}" );
            }
        }

        # something went wrong
        $Self->_AddEdit(
            %Error,
            %Param,
            %GetParam,
        );

        my $Output = $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();
        $Output .= $Error{Message}
            ? $Self->{LayoutObject}->Notify(
            Priority => 'Error',
            Info     => $Error{Message},
            )
            : '';

        $Output .= $Self->{LayoutObject}->Output(
            TemplateFile => 'AdminCustomerPortalGroup',
            Data         => \%Param,
        );
        $Output .= $Self->{LayoutObject}->Footer();
        return $Output;
    }

    # ------------------------------------------------------------
    # overview
    # ------------------------------------------------------------
    $Self->_Overview(
        Search => $GetParam{Search},
    );
    my $Output = $Self->{LayoutObject}->Header();
    $Output .= $Self->{LayoutObject}->NavigationBar();

    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminCustomerPortalGroup',
        Data         => \%Param,
    );

    $Output .= $Self->{LayoutObject}->Footer();
    return $Output;
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    $Self->{LayoutObject}->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $Self->{LayoutObject}->Block(
        Name => 'ActionOverview',
        Data => \%Param,
    );

    my $Limit = 400;
    my %List = $Self->{CustomerPortalGroupObject}->PortalGroupList(
        Search => $Param{Search},
        Limit  => $Limit + 1,
    );

    $Self->{LayoutObject}->Block(
        Name => 'OverviewHeader',
        Data => {
            ListSize => scalar(keys %List),
            Limit    => $Limit,
        },
    );

    $Self->{LayoutObject}->Block(
        Name => 'OverviewResult',
        Data => \%Param,
    );

    my %ValidList = $Self->{ValidObject}->ValidList();

    # if there are results to show
    if (%List) {
        for my $ID ( sort { $List{$a} cmp $List{$b} } keys %List ) {

            my %PortalGroup = $Self->{CustomerPortalGroupObject}->PortalGroupGet(
                PortalGroupID => $ID,
            );

            $Self->{LayoutObject}->Block(
                Name => 'OverviewResultRow',
                Data => {
                    Valid => $ValidList{ $PortalGroup{ValidID} },
                    %PortalGroup,
                }
            );

            if ($PortalGroup{Icon}) {
                $Self->{LayoutObject}->Block(
                    Name => 'OverviewDisplayIcon',
                    Data => $PortalGroup{Icon},
                );
            }
        }
    }

    # otherwise it displays a no data found message
    else {
        $Self->{LayoutObject}->Block(
            Name => 'NoDataFoundMsg',
            Data => {},
        );
    }
    return 1;
}

sub _AddEdit {
    my ( $Self, %Param ) = @_;
    my %PortalGroup;

    if ($Param{PortalGroupID}) {
        %PortalGroup = $Self->{CustomerPortalGroupObject}->PortalGroupGet(
            PortalGroupID => $Param{PortalGroupID},
        );
    }

    # build valid selection
    my %ValidHash = $Self->{ValidObject}->ValidList();
    $ValidHash{''} = '-';
    $Param{ValidOption} = $Self->{LayoutObject}->BuildSelection(
        Data       => \%ValidHash,
        Name       => 'ValidID',
        SelectedID => $Param{ValidID} || $PortalGroup{ValidID} || 1,
        Class      => 'Modernize',
    );

    $Self->{LayoutObject}->Block(
        Name => 'AddEdit',
        Data => {
            %PortalGroup,
            %Param,
        }
    );

    $Self->{LayoutObject}->Block(
        Name => 'ActionAddEdit',
        Data => \%Param,
    );

    if ($Param{PortalGroupID}) {
        $Self->{LayoutObject}->Block(
            Name => 'HeaderEdit',
            Data => \%Param,
        );

        if ($PortalGroup{Icon}) {
            $Self->{LayoutObject}->Block(
                Name => 'DisplayIcon',
                Data => $PortalGroup{Icon},
            );
        }
    }
    else {
        $Self->{LayoutObject}->Block(
            Name => 'HeaderAdd',
            Data => \%Param,
        );
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
