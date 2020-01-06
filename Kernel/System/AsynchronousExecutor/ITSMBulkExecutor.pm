# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AsynchronousExecutor::ITSMBulkExecutor;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::LinkObject',
    'Kernel::System::Scheduler',
    'Kernel::System::ITSMConfigItem'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{LinkObject}         = $Kernel::OM->Get('Kernel::System::LinkObject');
    $Self->{ConfigItemObject}   = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    $Self->{LogObject}          = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{SchedulerObject}    = $Kernel::OM->Get('Kernel::System::Scheduler');

    return $Self;
}

#------------------------------------------------------------------------------
# BEGIN run method
#
sub Run {
    my ( $Self, %Param ) = @_;

    if ( $Param{CallAction} eq 'ITSMBulkDo' ) {
        return $Self->_ITSMBulkDo(
            %Param,
        );
    }
}

sub _ITSMBulkDo {
    my ( $Self, %Param ) = @_;

    my %GetParam        = %{$Param{GetParam}};
    my $ConfigItemID    = $Param{ConfigItemID};
    my @ConfigItemIDs   = @{$Param{ConfigItemIDs}};
    my $XMLDefinition   = $Param{XMLDefinition};

    # bulk action version ddd
    if ( $GetParam{DeplStateID} || $GetParam{InciStateID} ) {

        # get current version of the config item
        my $CurrentVersion = $Self->{ConfigItemObject}->VersionGet(
            ConfigItemID => $ConfigItemID,
            XMLDataGet   => 1,
        );

        my $NewDeplStateID = $CurrentVersion->{DeplStateID};
        my $NewInciStateID = $CurrentVersion->{InciStateID};

        if ( IsNumber( $GetParam{DeplStateID} ) ) {
            $NewDeplStateID = $GetParam{DeplStateID};
        }
        if ( IsNumber( $GetParam{InciStateID} ) ) {
            $NewInciStateID = $GetParam{InciStateID};
        }

        my $VersionID = $Self->{ConfigItemObject}->VersionAdd(
            ConfigItemID => $ConfigItemID,
            Name         => $CurrentVersion->{Name},
            DefinitionID => $XMLDefinition->{DefinitionID},
            DeplStateID  => $NewDeplStateID,
            InciStateID  => $NewInciStateID,
            XMLData      => $CurrentVersion->{XMLData},
            UserID       => $Param{UserID},
        );
    }

    # bulk action links
    # link all config items to another config item
    if ( $GetParam{'LinkTogetherAnother'} ) {
        my $MainConfigItemID = $Self->{ConfigItemObject}->ConfigItemLookup(
            ConfigItemNumber => $GetParam{'LinkTogetherAnother'},
        );

        # split the type identifier
        my @Type = split q{::}, $GetParam{LinkType};

        if ( $Type[0] && $Type[1] && ( $Type[1] eq 'Source' || $Type[1] eq 'Target' ) ) {

            my $SourceKey = $ConfigItemID;
            my $TargetKey = $MainConfigItemID;

            if ( $Type[1] eq 'Target' ) {
                $SourceKey = $MainConfigItemID;
                $TargetKey = $ConfigItemID
            }

            for my $ConfigItemIDPartner (@ConfigItemIDs) {
                if ( $MainConfigItemID ne $ConfigItemIDPartner ) {
                    $Self->{LinkObject}->LinkAdd(
                        SourceObject => 'ITSMConfigItem',
                        SourceKey    => $SourceKey,
                        TargetObject => 'ITSMConfigItem',
                        TargetKey    => $TargetKey,
                        Type         => $Type[0],
                        State        => 'Valid',
                        UserID       => $Param{UserID},
                    );
                }
            }
        }
    }

    # link together
    if ( $GetParam{'LinkTogether'} ) {

        # split the type identifier
        my @Type = split q{::}, $GetParam{LinkTogetherLinkType};

        if ( $Type[0] && $Type[1] && ( $Type[1] eq 'Source' || $Type[1] eq 'Target' ) ) {
            for my $ConfigItemIDPartner (@ConfigItemIDs) {

                my $SourceKey = $ConfigItemID;
                my $TargetKey = $ConfigItemIDPartner;

                if ( $Type[1] eq 'Target' ) {
                    $SourceKey = $ConfigItemIDPartner;
                    $TargetKey = $ConfigItemID
                }

                if ( $ConfigItemID ne $ConfigItemIDPartner ) {
                    $Self->{LinkObject}->LinkAdd(
                        SourceObject => 'ITSMConfigItem',
                        SourceKey    => $SourceKey,
                        TargetObject => 'ITSMConfigItem',
                        TargetKey    => $TargetKey,
                        Type         => $Type[0],
                        State        => 'Valid',
                        UserID       => $Param{UserID},
                    );
                }
            }
        }
    }

    return {
        Success     => 1,
        ReSchedule  => 0,
    };
}

=item AsyncCall()

creates a scheduler daemon task to execute a function asynchronously.

    my $Success = $Object->AsyncCall(
        ObjectName               => 'Kernel::System::Ticket',   # optional, if not given the object is used from where
                                                                # this function was called
        FunctionName             => 'MyFunction',               # the name of the function to execute
        FunctionParams           => \%MyParams,                 # a ref with the required parameters for the function
        Attempts                 => 3,                          # optional, default: 1, number of tries to lock the
                                                                #   task by the scheduler
        MaximumParallelInstances => 1,                          # optional, default: 0 (unlimited), number of same
                                                                #   function calls form the same object that can be
                                                                #   executed at the the same time
    );

Returns:

    $Success = 1;  # of false in case of an error

=cut

sub AsyncCall {
    my ( $Self, %Param ) = @_;

    my $FunctionName = $Param{FunctionName};

    if ( !IsStringWithData($FunctionName) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Function needs to be a non empty string!",
        );
        return;
    }

    my $ObjectName = $Param{ObjectName} || ref $Self;

    # create a new object
    my $LocalObject;
    eval {
        $LocalObject = $Kernel::OM->Get($ObjectName);
    };

    # check if is possible to create the object
    if ( !$LocalObject ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Could not create $ObjectName object!",
        );
        return;
    }

    # check if object reference is the same as expected
    if ( ref $LocalObject ne $ObjectName ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "$ObjectName object is not valid!",
        );
        return;
    }

    # check if the object can execute the function
    if ( !$LocalObject->can($FunctionName) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "$ObjectName can not execute $FunctionName()!",
        );
        return;
    }

    if ( $Param{FunctionParams} && !ref $Param{FunctionParams} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "FunctionParams needs to be a hash or list reference.",
        );
        return;
    }

    # create a new task
    my $TaskID = $Self->{SchedulerObject}->TaskAdd(
        Type                     => 'AsynchronousExecutor',
        Name                     => $Param{TaskName},
        Attempts                 => $Param{Attempts} || 1,
        MaximumParallelInstances => $Param{MaximumParallelInstances} || 0,
        Data                     => {
            Object   => $ObjectName,
            Function => $FunctionName,
            Params   => $Param{FunctionParams} // {},
        },
    );

    if ( !$TaskID ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Could not create new AsynchronousExecutor: '$Param{TaskName}' task!",
        );
        return;
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
