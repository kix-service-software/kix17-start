# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::ExternalSupplierForwarding;

use strict;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Ticket',
    'Kernel::System::Log',
    'Kernel::System::Queue',
    'Kernel::System::AsynchronousExecutor::ExternalSupplierForwarding',
);

sub new {
    my $Type  = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    #check required params...
    foreach (qw( Data Event Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }
    for (qw(TicketID)) {
        if ( !$Param{Data}->{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "Need $_ in Data!" );
            return;
        }
    }

    # get configuration
    my $FwdQueueRef =
        $Kernel::OM->Get('Kernel::Config')->Get('ExternalSupplierForwarding::ForwardQueues');
    my $FwdQueueNames = keys( %{$FwdQueueRef} );
    my $RelevantFwdArticleTypesRef =
        $Kernel::OM->Get('Kernel::Config')
        ->Get('ExternalSupplierForwarding::RelevantFwdArticleTypes');

    #get ticket data...
    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => 1,
    );

    #-----------------------------------------------------------------------------
    #check if it's a forward queue...
    if ( $FwdQueueRef->{ $Ticket{Queue} } ) {
        my $FirstArticleFlag  = 0;
        my %ArticleOfInterest = ();
        my @ArticleIDs        = qw{};
        my @Articles          = $TicketObject->ArticleContentIndex(
            TicketID    => $Param{Data}->{TicketID},
            ArticleType => $RelevantFwdArticleTypesRef,
            UserID      => $Self->{UserID} || 1,
        );
        return if ( !@Articles );
        for my $CurrArticle (@Articles) {
            next if ( ref($CurrArticle) ne 'HASH' );
            push( @ArticleIDs, $CurrArticle->{ArticleID} )
        }

        #-----------------------------------------------------------------------
        # get first relevant article....
        %ArticleOfInterest = %{ $Articles[0] };

        #-----------------------------------------------------------------------
        # check for "ArticleCreate" event...
        if ( ( $Param{Event} eq "ArticleCreate" ) && ( $Param{Data}->{ArticleID} ) ) {
            if (
                ( $Articles[0] )
                && ( ref( $Articles[0] ) eq 'HASH' )
                && ( $Param{Data}->{ArticleID} != $Articles[0]->{ArticleID} )
                )
            {

                # check if article is in list of relevant articles...
                return if ( !( grep { $_ eq $Param{Data}->{ArticleID} } @ArticleIDs ) );

                # get article...
                %ArticleOfInterest = $TicketObject->ArticleGet(
                    ArticleID => $Param{Data}->{ArticleID},
                );
            }
            else {
                $FirstArticleFlag = 1;
            }
        }

        #-----------------------------------------------------------------------
        # check for "QueueUpdate" event...
        elsif ( $Param{Event} eq "TicketQueueUpdate" ) {
            $FirstArticleFlag = 1;
        }

        #-----------------------------------------------------------------------
        # get relevant mail addresses...
        my $DestMailAdress = $FwdQueueRef->{ $Ticket{Queue} };
        my %FromAddress    = $Kernel::OM->Get('Kernel::System::Queue')->GetSystemAddress(
            QueueID => $Ticket{QueueID},
        );

        #-----------------------------------------------------------------------
        # create ScheduleJob ...
        my %JobParam = (
            TicketID         => $Param{Data}->{TicketID},
            ArticleID        => $ArticleOfInterest{ArticleID} || 0,
            DestMailAddress  => $DestMailAdress,
            FromMailAddress  => $FromAddress{Email},
            FirstArticleFlag => $FirstArticleFlag || '',
        );
        my $Success
            = $Kernel::OM->Get('Kernel::System::AsynchronousExecutor::ExternalSupplierForwarding')
            ->AsyncCall(
            ObjectName     => 'Kernel::System::AsynchronousExecutor::ExternalSupplierForwarding',
            FunctionName   => 'Run',
            FunctionParams => \%JobParam,
            Attempts       => 1,
            MaximumParallelInstances => 1,
            );
        if ( !$Success ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'ExternalSupplierForwarding - could not add AsyncCall',
            );
        }
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
