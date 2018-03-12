# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ProcessManagement::ActivityDialog;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::ProcessManagement::ActivityDialog - activity dialog lib

=head1 SYNOPSIS

All Process Management Activity Dialog functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ActivityDialogObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::ActivityDialog');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item ActivityDialogGet()

    Get activity dialog info

    my $ActivityDialog = $ActivityDialogObject->ActivityDialogGet(
        ActivityDialogEntityID => 'AD1',
        Interface              => ['AgentInterface'],   # ['AgentInterface'] or ['CustomerInterface'] or ['AgentInterface', 'CustomerInterface'] or 'all'
        Silent                 => 1,    # 1 or 0, default 0, if set to 1, will not log errors about not matching interfaces
    );

    Returns:

    $ActivityDialog = {
        Name             => 'UnitTestActivity',
        Interface        => 'CustomerInterface',   # 'AgentInterface', 'CustomerInterface', ['AgentInterface'] or ['CustomerInterface'] or ['AgentInterface', 'CustomerInterface']
        DescriptionShort => 'AD1 Process Short',
        DescriptionLong  => 'AD1 Process Long description',
        CreateTime       => '07-02-2012 13:37:00',
        CreateBy         => '2',
        ChangeTime       => '08-02-2012 13:37:00',
        ChangeBy         => '3',
        Fields => {
            DynamicField_Make => {
                Display          => 2,
                DescriptionLong  => 'Make Long',
                DescriptionShort => 'Make Short',
            },
            DynamicField_VWModel => {
                Display          => 2,
                DescriptionLong  => 'VWModel Long',
                DescriptionShort => 'VWModel Short',
            },
            DynamicField_PeugeotModel => {
                Display          => 0,
                DescriptionLong  => 'PeugeotModel Long',
                DescriptionShort => 'PeugeotModel Short',
            },
            StateID => {
               Display          => 1,
               DescriptionLong  => 'StateID Long',
               DescriptionShort => 'StateID Short',
            },
        },
        FieldOrder => [
            'StateID',
            'DynamicField_Make',
            'DynamicField_VWModelModel',
            'DynamicField_PeugeotModel'
        ],
        SubmitAdviceText => 'NOTE: If you submit the form ...',
        SubmitButtonText => 'Make an inquiry',
    };

=cut

sub ActivityDialogGet {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(ActivityDialogEntityID Interface)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if ( $Param{Interface} ne 'all' && ref $Param{Interface} ne 'ARRAY' ) {
        $Param{Interface} = [ $Param{Interface} ];
    }

    my $ActivityDialog = $Kernel::OM->Get('Kernel::Config')->Get('Process::ActivityDialog');

    if ( !IsHashRefWithData($ActivityDialog) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ActivityDialog config!'
        );
        return;
    }

    if ( !IsHashRefWithData( $ActivityDialog->{ $Param{ActivityDialogEntityID} } ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No Data for ActivityDialog '$Param{ActivityDialogEntityID}' found!"
        );
        return;
    }

    if (
        $Param{Interface} ne 'all'
        && !IsArrayRefWithData(
            $ActivityDialog->{ $Param{ActivityDialogEntityID} }->{Interface}
        )
        )
    {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No Interface for ActivityDialog '$Param{ActivityDialogEntityID}' found!"
        );
    }

    if ( $Param{Interface} ne 'all' ) {
        my $Success;
        INTERFACE:
        for my $CurrentInterface ( @{ $Param{Interface} } ) {
            if (
                grep { $CurrentInterface eq $_ }
                @{ $ActivityDialog->{ $Param{ActivityDialogEntityID} }->{Interface} }
                )
            {
                $Success = 1;
                last INTERFACE;
            }
        }

        if ( !$Success ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Not permitted Interface(s) '"
                        . join( '\', \'', @{ $Param{Interface} } )
                        . "' for ActivityDialog '$Param{ActivityDialogEntityID}'!"
                );
            }
            return;
        }
    }

    return $ActivityDialog->{ $Param{ActivityDialogEntityID} };
}

=item ActivityDialogCompletedCheck()

    Checks if an activity dialog is completed

    my $Completed = $ActivityDialogObject->ActivityDialogCompletedCheck(
        ActivityDialogEntityID => 'AD1',
        Data                   => {
            Queue         => 'Raw',
            DynamicField1 => 'Value',
            Subject       => 'Testsubject',
            # ...
        },
    );

    Returns:

    $Completed = 1; # 0

=cut

sub ActivityDialogCompletedCheck {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(ActivityDialogEntityID Data)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if ( !IsHashRefWithData( $Param{Data} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Data has no values!",
        );
        return;
    }

    my $ActivityDialog = $Self->ActivityDialogGet(
        ActivityDialogEntityID => $Param{ActivityDialogEntityID},
        Interface              => 'all',
    );
    if ( !$ActivityDialog ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Can't get ActivtyDialog '$Param{ActivityDialogEntityID}'!",
        );
        return;
    }

    if ( !$ActivityDialog->{Fields} || ref $ActivityDialog->{Fields} ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Can't get fields for ActivtyDialog '$Param{ActivityDialogEntityID}'!",
        );
        return;
    }

    # loop over the fields of the config activity dialog to check if the required fields are filled
    FIELDLOOP:
    for my $Field ( sort keys %{ $ActivityDialog->{Fields} } ) {

        # Checks if Field was invisible
        next FIELDLOOP if ( !$ActivityDialog->{Fields}{$Field}{Display} );

        # Checks if Field was visible but not required
        next FIELDLOOP if ( $ActivityDialog->{Fields}{$Field}{Display} == 1 );

        # checks if $Data->{Field} is defined and not an empty string
        return if ( !IsStringWithData( $Param{Data}->{$Field} ) );
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
