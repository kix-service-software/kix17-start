# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SystemMessage;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::DB',
    'Kernel::System::Valid',
    'Kernel::System::Main',
    'Kernel::System::YAML',
);

=head1 NAME

Kernel::System::SystemMessage - signature lib

=head1 SYNOPSIS

All signature functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::SystemMessage');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item MessageAdd()

add news

    my $ID = $SystemMessageObject->MessageAdd(
        Title    => 'Some Message',
        ValidID  => 123,
        Config   => 'YAML-Conent'
        UserID   => 123,
    );

=cut

sub MessageAdd {
    my ($Self, %Param) = @_;

    # get needed objects
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

    for ( qw(UserID Templates ValidID Title ShortText Body) ) {
        if ( !defined( $Param{$_} ) ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Config;
    for ( qw(Templates ShortText Body ValidTo ValidFrom UsedDashboard) ) {
        $Config{$_} = $Param{$_} || '';
    }

    my $ConfigStrg = $YAMLObject->Dump(
        Data => \%Config
    );

    # sql
    return if !$DBObject->Do(
        SQL => '
            INSERT INTO kix_system_message (
                title, valid_id, config, create_time, create_by, change_time, change_by
            )
            VALUES (?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Title},   \$Param{ValidID},
            \$ConfigStrg,     \$Param{UserID},
            \$Param{UserID},
        ],
    );

    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM kix_system_message WHERE title = ? AND change_by = ?',
        Bind => [ \$Param{Title}, \$Param{UserID}, ],
    );

    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return $ID;
}

=item MessageUpdate()

update news

    my $Success = $SystemMessageObject->MessageUpdate(
        ID       => '123',
        Title    => 'Message',
        ValidID  => 123,
        Config   => 'YAML-Conent'
        UserID   => 123,
    );

=cut
sub MessageUpdate {
    my ($Self, %Param) = @_;

    # get needed objects
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

    for ( qw(MessageID UserID Templates ValidID Title ShortText Body) ) {
        if ( !defined( $Param{$_} ) ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }


    my %Config;
    for ( qw(Templates ShortText Body ValidTo ValidFrom UsedDashboard) ) {
        $Config{$_} = $Param{$_} || '';
    }

    my $ConfigStrg = $YAMLObject->Dump(
        Data => \%Config
    );

    # sql
    return if !$DBObject->Do(
        SQL => '
            UPDATE kix_system_message
            SET
                title = ?,
                valid_id = ?,
                config   = ?,
                change_time = current_timestamp,
                change_by = ?
            WHERE id = ?',
        Bind => [
            \$Param{Title}, \$Param{ValidID},
            \$ConfigStrg,   \$Param{UserID},
            \$Param{MessageID}
        ],
    );

    return 1;
}

=item MessageDelete()

delete a news

    $SystemMessageObject->MessageDelete(
        ID => 123,
    );

=cut

sub MessageDelete {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    if ( !$Param{ID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need ID!'
        );
        return;
    }

    # sql
    return if !$DBObject->Do(
        SQL  => 'DELETE
            FROM kix_system_message
            WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    return 1;
}

=item MessageList()

get all valid newss

    my %Messages = $SystemMessageObject->MessageList();

Returns:
    %Messages = (
        1 => 'Some Name',
        2 => 'Some Name2',
        3 => 'Some Name3',
    );

get all newss

    my %Messages = $SystemMessageObject->MessageList(
        Valid => 0,
    );

Returns:
    %Messages = (
        1 => 'Some Name',
        2 => 'Some Name2',
    );

=cut

sub MessageList {
    my ( $Self, %Param ) = @_;

    # get needed object
    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');

    my $Valid = 1;
    if ( defined $Param{Valid}
         && !$Param{Valid}
    ) {
        $Valid = 0;
    }

    my $SQL = '
        SELECT id, title
        FROM kix_system_message';

    if ($Valid) {
        $SQL .= ' WHERE valid_id IN ('
            . join( ', ', $ValidObject->ValidIDsGet())
            . ')';
    }

    my @Bind;
    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    return %Data;
}

=item MessageSearch()

search for message

    my %Message = $SystemMessageObject->MessageSearch(
        Search  => '*some*',           # optional
        Valid   => 1,                  # optional defaul(0)
    );

Returns:
    %Message = (
        1 => 'Some Name',
        2 => 'Some Name2',
        3 => 'Some Name3',
    );

search with used action and active state or valid date

    my %Message = $SystemMessageObject->MessageSearch(
        Action   => 'AgentTicketPhone', # optional
        Valid    => 1,                  # optional defaul(0)
        UserID   => 1,                  # optional
        UserType => 'user'              # required if UserID used
    );

Returns:
    %Message = (
        1 => 'Some Name',
        2 => 'Some Name2',
        3 => 'Some Name3',
    );

search on valid date check

    my %Message = $SystemMessageObject->MessageSearch(
        DateCheck => 1,                 # optional
        Valid     => 1,                 # optional defaul(0)
    );

Returns:
    %Message = (
        1 => 'Some Name',
        2 => 'Some Name2',
        3 => 'Some Name3',
    );
=cut

sub MessageSearch {
    my ( $Self, %Param ) = @_;

    # get needed object
    my $ValidObject        = $Kernel::OM->Get('Kernel::System::Valid');
    my $StateObject        = $Kernel::OM->Get('Kernel::System::State');
    my $DBObject           = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $TimeObject         = $Kernel::OM->Get('Kernel::System::Time');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    my @Bind;
    my $Valid = 1;
    if ( defined $Param{Valid}
         && !$Param{Valid}
    ) {
        $Valid = 0;
    }

    my $SQLWhere = '';
    my $SQL      = '
        SELECT id, title
        FROM kix_system_message
        WHERE';

    if ($Valid) {
        $SQLWhere .= ' valid_id IN ('
            . join( ', ', $ValidObject->ValidIDsGet())
            . ')';
    }

    if ( $Param{Search} ) {
        my %QueryCondition = $DBObject->QueryCondition(
            Key      => ['title'],
            Value    => $Param{Search},
            BindMode => 1,
        );

        $SQLWhere .= ' AND' if $SQLWhere;
        $SQLWhere .= ' ' . $QueryCondition{SQL};
        push( @Bind, @{ $QueryCondition{Values} });
    }

    my %UserReads;
    if ( $Param{UserID} ) {

        # check needed stuff
        if ( !$Param{UserType} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => 'Need UserType by using UserID!'
            );
            return;
        }

        my %Preferences;
        if ( $Param{UserType} eq  'User' ) {
            %Preferences = $UserObject->GetPreferences(
                UserID => $Param{UserID},
            );
        }

        elsif ( $Param{UserType} eq 'Customer' ) {
            %Preferences = $CustomerUserObject->GetPreferences(
                UserID => $Param{UserID},
            );
        }

        if ( $Preferences{UserMessageRead} ) {
            %UserReads = map( { $_ => 1 } split( /;/, $Preferences{UserMessageRead} || '') );
        }
    }

    return if !$DBObject->Prepare(
        SQL  => $SQL . $SQLWhere,
        Bind => \@Bind,
    );

    my $SystemTime = $TimeObject->SystemTime();
    my %Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Result{ $Row[0] } = $Row[1];
    }

    for my $MessageID ( sort keys %Result ) {
        my %Data = $Self->MessageGet(
            MessageID => $MessageID
        );

        if ( $Param{Action} ) {
            if (
                !grep( { $Param{Action} eq $_} @{$Data{Templates}} )
                || (
                    $Data{ValidFrom}
                    && $Data{ValidFrom} > $SystemTime
                )
                || (
                    $Data{ValidTo}
                    &&  $Data{ValidTo} < $SystemTime
                )
                || $UserReads{$MessageID}
            ) {
                delete $Result{ $MessageID };
            }
        }

        elsif ( $Param{DateCheck} ) {
            if (
                (
                    $Data{ValidFrom}
                    && $Data{ValidFrom} > $SystemTime
                )
                || (
                    $Data{ValidTo}
                    &&  $Data{ValidTo} < $SystemTime
                )
            ) {
                delete $Result{ $MessageID };
            }
        }
    }

    return %Result;
}

=item MessageGet()

get news all attributes

    my %Message = $SystemMessageObject->MessageGet(
        MessageID => 123,
    );

Returns:

    %Message = (
        MessageID     => '123',
        Title         => 'Simple message',
        ValidID       => '1',
        ShortText     => 'Some short text',
        Body          => 'Some news text',
        ValidFrom     => 'Timestamp',
        ValidTo       => 'Timestamp',
        Templates     => [...],
        UsedDashboard => 1
        Created       => '2010-04-07 15:41:15',
        Changed       => '2010-04-07 15:59:45',
    );

=cut
sub MessageGet {
    my ($Self, %Param) = @_;

    # get needed objects
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');
    my $YAMLObject  = $Kernel::OM->Get('Kernel::System::YAML');
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    if ( !$Param{MessageID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Needed MessageID!"
        );
        return;
    }

    return if !$DBObject->Prepare(
        SQL  => 'SELECT id, title, valid_id, config, create_time, create_by, change_time, change_by
            FROM kix_system_message
            WHERE id = ?',
        Bind => [\$Param{MessageID}]
    );

    # fetch the result
    my %Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        %Result = (
            MessageID => $Row[0],
            Title     => $Row[1],
            ValidID   => $Row[2],
            Created   => $Row[4],
            CreatedBy => $Row[5],
            Created   => $Row[6],
            ChangedBy => $Row[7]
        );

        if ( $Row[3] ) {
            my $Data = $YAMLObject->Load(
                Data => $Row[3]
            );

            for my $Key ( sort keys %{$Data} ) {
                $Result{$Key} = $Data->{$Key} || '';
            }
        }
    }

    return %Result;
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
