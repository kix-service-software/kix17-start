# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::CustomerTicketCustomerIDSelection;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get form id
    $Self->{FormID} = $ParamObject->GetParam( Param => 'FormID' );

    # create form id
    if ( !$Self->{FormID} ) {
        $Self->{FormID} = $Kernel::OM->Get('Kernel::System::Web::UploadCache')->FormIDCreate();
    }

    $Self->{Config} = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    return $Self;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Output;
    return if ( $Self->{Action} ne 'CustomerTicketMessage' );

    for my $CurrParam (qw{SelectedCustomerID DefaultSet}) {
        $Param{$CurrParam} = $ParamObject->GetParam( Param => $CurrParam ) || '';
    }
    return if $Param{SelectedCustomerID};

    # get all customer ids
    my @CustomerIDArray = $CustomerUserObject->CustomerIDs(
        User => $Self->{UserID},
    );

    if ( ( grep { $_ eq $Self->{UserCustomerID}; } @CustomerIDArray ) == 0 ) {
        push( @CustomerIDArray, $Self->{UserCustomerID} );
    }

    if ( scalar(@CustomerIDArray) > 1 ) {
        return $LayoutObject->Redirect(
            OP => "Action=CustomerTicketCustomerIDSelection;DefaultSet=" . $Param{DefaultSet},
        );
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    my %GetParam = ();
    for my $CurrParam (qw{SelectedCustomerID DefaultSet}) {
        $GetParam{$CurrParam} = $ParamObject->GetParam( Param => $CurrParam );
    }

    if ( !$Self->{Subaction} ) {
        my @CustomerIDArray = $CustomerUserObject->CustomerIDs(
            User => $Self->{UserID},
        );

        if ( ( grep { $_ eq $Self->{UserCustomerID}; } @CustomerIDArray ) == 0 ) {
            push( @CustomerIDArray, $Self->{UserCustomerID} );
        }

        if ( scalar(@CustomerIDArray) < 2 ) {
            return $LayoutObject->Redirect(
                OP => "Action=CustomerTicketMessage"
                    . ";SelectedCustomerID=" . $Self->{UserCustomerID}
                    . ";DefaultSet=" . $GetParam{DefaultSet}
            );
        }

        my $Output .= $LayoutObject->CustomerHeader();
        $Output .= $LayoutObject->CustomerNavigationBar();
        $Output .= $Self->_MaskNew( %Param, %GetParam, CustomerIDArray => \@CustomerIDArray );
        $Output .= $LayoutObject->CustomerFooter();
        return $Output;
    }
    elsif ( $Self->{Subaction} eq 'NewTicket' ) {

        # pass selected CustomerID and product and redirect to ticket creation mask...
        return $LayoutObject->Redirect(
            OP => "Action=CustomerTicketMessage"
                . ";SelectedCustomerID=" . $GetParam{SelectedCustomerID}
                . ";DefaultSet=" . $GetParam{DefaultSet}
        );

    }

    # this should never happen, however...
    my $Output = $LayoutObject->CustomerHeader( Title => 'Error' );
    $Output .= $LayoutObject->CustomerError(
        Message => 'No valid subaction!',
        Comment => 'Please contact your administrator',
    );
    $Output .= $LayoutObject->CustomerFooter();
    return $Output;
}

sub _MaskNew {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ParamObject           = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject          = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');

    my @ItemList;
    my @CustomerIDArray = @{ $Param{CustomerIDArray} };
    for my $CurrCustomerID ( sort(@CustomerIDArray) ) {

        # get customer data
        my %CustomerData = $CustomerCompanyObject->CustomerCompanyGet(
            CustomerID => $CurrCustomerID,
        );

        my @ItemColumns = (
            {
                Type         => 'Radiobutton',
                Name         => 'SelectedCustomerRadio',
                ID           => 'SelectedCustomerRadio' . $CurrCustomerID,
                Content      => $CurrCustomerID,
                Title        => 'Select customer ID: %s',
                TitleContent => $CurrCustomerID,
                Css          => 'SelectedCustomerRadio',
            },
            {
                Type         => 'Label',
                LabelRef     => 'SelectedCustomerRadio' . $CurrCustomerID,
                Title        => 'Select customer ID: %s',
                TitleContent => $CurrCustomerID,
                Content      => "$CustomerData{CustomerCompanyName} ($CurrCustomerID)",
                MaxLength    => 100,
                Css          => 'SelectedCustomerRadioLabel',
            },
        );
        push @ItemList, \@ItemColumns;
    }

    # define table headline...
    my %Block = (

        #Headline => [
        #    {
        #        Content => 'Selection',
        #    },
        #    {
        #        Content => 'CustomerID',
        #    },
        #],
        ItemList => \@ItemList,
    );

    my $LayoutObject2 = Kernel::Output::HTML::Layout->new( %{$Self} );

    $LayoutObject->Block(
        Name => 'CustomerIDSelection',
        Data => \%Param,
    );

    for my $HeadlineColumn ( @{ $Block{Headline} } ) {
        $LayoutObject->Block(
            Name => 'TableBlockColumn',
            Data => $HeadlineColumn,
        );
    }

    for my $Row ( @{ $Block{ItemList} } ) {
        $LayoutObject->Block(
            Name => 'TableBlockRow',
            Data => $Row,
        );
        for my $Column ( @{$Row} ) {
            my $Content = $Self->_LinkObjectContentStringCreate(
                LayoutObject => $LayoutObject2,
                ContentHash  => $Column,
            );

            $LayoutObject->Block(
                Name => 'TableBlockRowColumn',
                Data => {
                    Content => $Content,
                },
            );
        }
    }

    # get output back
    return $LayoutObject->Output(
        TemplateFile => 'CustomerTicketCustomerIDSelection',
        Data         => \%Param,
    );
}

#-------------------------------------------------------------------------------
# internal methods....

sub _LinkObjectContentStringCreate {
    my ( $Self, %Param ) = @_;

    my $Blockname = '';

    # get needed objects
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');

    for my $Argument (qw(ContentHash)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    $Blockname = $Param{ContentHash}->{Type} || 'Plain';

    # run block
    $Param{LayoutObject}->Block(
        Name => $Blockname,
        Data => $Param{ContentHash},
    );

    return $Param{LayoutObject}->Output(
        TemplateFile => 'CustomerTicketCustomerIDSelection',
    );
}

# EO internal methods
#-------------------------------------------------------------------------------

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
