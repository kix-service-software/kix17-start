# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ProcessManagement::TransitionAction::Base;

use strict;
use warnings;

use utf8;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (

    # BPMX-capeIT
    'Kernel::Config',
    'Kernel::System::Encode',
    'Kernel::System::HTMLUtils',
    'Kernel::System::Main',
    'Kernel::System::Queue',
    'Kernel::System::TemplateGenerator',
    'Kernel::System::Ticket',

    # EO BPMX-capeIT
    'Kernel::System::Log',
);

# BPMX-capeIT
sub ArticleLastArticle {

    # result is ArticleID from last article from Ticket
    # Code from sub ArticleFirstArticle (Kernel/System/Ticket/Article.pm)
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error', Message => "Need TicketID!"
        );
        return;
    }

    # get article index
    my @Index = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleIndex(
        TicketID => $Param{TicketID}
    );

    # get article data
    return if !@Index;

    my $LastArticleID = @Index - 1;

    return $Kernel::OM->Get('Kernel::System::Ticket')->ArticleGet(
        ArticleID     => $Index[$LastArticleID],
        Extended      => $Param{Extended},
        DynamicFields => $Param{DynamicFields},
    );
}

sub ReplaceExtended {

    # Extension Placeholder
    # additionel Placeholder KIX_LAST_...
    # PriorityID, To, ArticleType, AgeTimeUnix, Body, MimeType, InReplyTo, TicketNumber,
    # SenderTypeID, ContentCharset, ResponsibleID, ReplyTo, EscalationSolutionTime,
    # SLA, EscalationUpdateTime, CreateTimeUnix, EscalationResponseTime, UntilTime,
    # ArticleTypeID, ServiceID, FromRealname, From, Changed, MessageID, State,
    # References, TypeID, Subject, ContentType, SenderType, QueueID, Title,
    # Responsible, LockID, Age, Owner, TicketID, Priority, Created, Lock, Queue,
    # CustomerUserID, CreatedBy, StateType, OwnerID, Service, ArticleID, Cc,
    # CustomerID, StateID, IncomingTime, Type, RealTillTimeNotUsed, EscalationTime, SLAID, Charset,
    # Idea: Code from sub _Replace

    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text RichText Data UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error', Message => "Need $_!"
            );
            return;
        }
    }

    my $Start = '<';
    my $End   = '>';
    if ( $Param{RichText} ) {
        $Start = '&lt;';
        $End   = '&gt;';
        $Param{Text} =~ s/(\n|\r)//g;
    }

    my %Ticket;
    if ( $Param{TicketID} ) {
        %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 1,
        );
    }

    # translate ticket values if needed
    if ( $Param{Language} ) {
        my $LanguageObject = Kernel::Language->new(
            MainObject   => $Kernel::OM->Get('Kernel::System::Main'),
            ConfigObject => $Kernel::OM->Get('Kernel::Config'),
            EncodeObject => $Kernel::OM->Get('Kernel::System::Encode'),
            LogObject    => $Kernel::OM->Get('Kernel::System::Log'),
            UserLanguage => $Param{Language},
        );
        for my $Field (qw(Type State StateType Lock Priority)) {
            $Ticket{$Field} = $LanguageObject->Translate( $Ticket{$Field} );
        }
    }

    my %Queue;
    if ( $Param{QueueID} ) {
        %Queue = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet( ID => $Param{QueueID} );
    }

#rbo - T2016121190001552 - added KIX placeholders
    my $Tag = $Start . '(KIX|OTRS)_LAST_';
    if ( $Param{Text} =~ /$Tag.+$End/i ) {

        # get last article data and replace it with <KIX_LAST_...
        my %Article = $Self->ArticleLastArticle(
            TicketID => $Param{TicketID},
        );

#rbo - T2016121190001552 - added KIX placeholders
        # replace <KIX_LAST_BODY> and <KIX_LAST_COMMENT> tags
        for my $Key (qw(KIX_LAST_BODY KIX_LAST_COMMENT OTRS_LAST_BODY OTRS_LAST_COMMENT)) {
            my $Tag2 = $Start . $Key;
            if ( $Param{Text} =~ /$Tag2$End(\n|\r|)/g ) {
                my $Line       = 2500;
                my @Body       = split( /\n/, $Article{Body} );
                my $NewOldBody = '';
                for ( my $i = 0; $i < $Line; $i++ ) {
                    if ( $#Body >= $i ) {

                        # add no quote char, do it later by using DocumentStyleCleanup()
                        if ( $Param{RichText} ) {
                            $NewOldBody .= $Body[$i];
                        }

                        # add "> " as quote char
                        else {
                            $NewOldBody .= "> $Body[$i]";
                        }

                        # add new line
                        if ( $i < ( $Line - 1 ) ) {
                            $NewOldBody .= "\n";
                        }
                    }
                    else {
                        last;
                    }
                }
                chomp $NewOldBody;

                # html quoting of content
                if ( $Param{RichText} && $NewOldBody ) {

                    # remove trailing new lines
                    for ( 1 .. 10 ) {
                        $NewOldBody =~ s/(<br\/>)\s{0,20}$//gs;
                    }

                    # add quote
                    $NewOldBody = "<blockquote type=\"cite\">$NewOldBody</blockquote>";
                    $NewOldBody
                        = $Kernel::OM->Get('Kernel::System::HTMLUtils')->DocumentStyleCleanup(
                        String => $NewOldBody,
                        );

                }

                # replace tag
                $Param{Text} =~ s/$Tag2$End/$NewOldBody/g;
            }
        }

#rbo - T2016121190001552 - added KIX placeholders
        # replace <KIX_LAST_SUBJECT[]> tags
        my $Tag2 = $Start . '(KIX|OTRS)_LAST_SUBJECT';
        if ( $Param{Text} =~ /$Tag2\[(.+?)\]$End/g ) {
            my $SubjectChar = $2;

            # my $Subject     = $TicketObject->TicketSubjectClean(
            my $Subject = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSubjectClean(
                TicketNumber => $Ticket{TicketNumber},
                Subject      => $Article{Subject},
            );
            $Subject =~ s/^(.{$SubjectChar}).*$/$2 [...]/;
            $Param{Text} =~ s/$Tag2\[.+?\]$End/$Subject/g;
        }

        # html quoteing of content
        if ( $Param{RichText} ) {
            for ( keys %Article ) {
                next if !$Article{$_};
                $Article{$_} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML(
                    String => $Article{$_},
                );

            }
        }

        # replace it
        for my $Key ( keys %Article ) {
            next if !defined $Article{$Key};
            $Param{Text} =~ s/$Tag$Key$End/$Article{$Key}/gi;
        }

        # cleanup all not needed <KIX_LAST_ tags
        $Param{Text} =~ s/$Tag.+?$End/-/gi;

    }
    else
    {
        # using TemplateGenerator from KIX4OTRS
        $Param{Text} = $Kernel::OM->Get('Kernel::System::TemplateGenerator')->ReplacePlaceHolder(
            RichText => $Param{RichText},
            Text     => $Param{Text},
            TicketID => $Param{TicketID},
            Data     => $Param{Data},
            UserID   => $Param{UserID},
        );

    }

    return $Param{Text};

}
# EO BPMX-capeIT

sub _CheckParams {
    my ( $Self, %Param ) = @_;

    my $CommonMessage = $Param{CommonMessage};

    for my $Needed (
        qw(UserID Ticket ProcessEntityID ActivityEntityID TransitionEntityID
        TransitionActionEntityID Config
        )
        )
    {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # Check if we have Ticket to deal with
    if ( !IsHashRefWithData( $Param{Ticket} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => $CommonMessage . "Ticket has no values!",
        );
        return;
    }

    # Check if we have a ConfigHash
    if ( !IsHashRefWithData( $Param{Config} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => $CommonMessage . "Config has no values!",
        );
        return;
    }

    return 1;
}

sub _OverrideUserID {
    my ( $Self, %Param ) = @_;

    if ( IsNumber( $Param{Config}->{UserID} ) ) {
        $Param{UserID} = $Param{Config}->{UserID};
        delete $Param{Config}->{UserID};
    }

    return $Param{UserID};
}

sub _ReplaceTicketAttributes {
    my ( $Self, %Param ) = @_;

# BPMX-capeIT
#    include more Placeholder
#
#   # get needed objects
#
# ...
# Repleace from file Kernel/System/ProcessManagement/TransitionAction/Base.pm (version otrs 5.0.12) line 80 to 129
# ...

    for my $Attribute ( sort keys %{ $Param{Config} } ) {
        $Param{Config}->{$Attribute} = $Self->ReplaceExtended(
            RichText => '0',
            Text     => $Param{Config}->{$Attribute},
            TicketID => $Param{Ticket}->{TicketID} || '',
            Data     => $Param{Data} || {},
            UserID   => $Param{UserID} || 1,
        );
    }

    # EO BPMX-capeIT
    return 1;
}

sub _ConvertScalar2ArrayRef {
    my ( $Self, %Param ) = @_;

    # BPMX-capeIT
    #    my @Data = split /,/, $Param{Data};
    my @Data = split( '/,/,', $Param{Data} );

    # EO BPMX-capeIT

    # remove any possible heading and tailing white spaces
    for my $Item (@Data) {
        $Item =~ s{\A\s+}{};
        $Item =~ s{\s+\z}{};
    }

    return \@Data;
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
