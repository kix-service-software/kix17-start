# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketTemplateHandler;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::Ticket::TicketTemplateHandler - ticket template lib

=head1 SYNOPSIS

All ticket template functions.

=over 4

=cut

=item TicketTemplateList()

Returns all ticket templates

    my %Hash = $TicketTemplateObject->TicketTemplateList(
        ValidID  => 1           # optional, 1 or 0
        Frontend => 'Agent'     # optional, 'Customer' or 'Agent'
    );

    my @Array = $TicketTemplateObject->TicketTemplateList(
        ValidID  => 1           # optional, 1 or 0
        Frontend => 'Agent'     # optional, 'Customer' or 'Agent'
        Result   => 'Name'      # 'Name' or 'ID'
    );

=cut

sub TicketTemplateList {
    my ( $Self, %Param ) = @_;

    # check if result is cached
    my $CacheKey = 'Cache::TicketTemplateList';
    if ( $Self->{$CacheKey} ) {
        return %{ $Self->{$CacheKey} };
    }

    # get ticket templates
    my %Templates;
    my $SQL = 'SELECT id, name FROM kix_ticket_template';

    # get DB object
    $Self->{DBObject}     = $Kernel::OM->Get('Kernel::System::DB');
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');

    if ( defined $Param{ValidID} && $Param{ValidID} ) {
        $Param{ValidID} = $Self->{DBObject}->Quote( $Param{ValidID}, 'Integer' );
        $SQL .= ' WHERE valid_id = ' . $Param{ValidID};
    }

    if ( defined $Param{Frontend} && $Param{Frontend} ) {
        my $Column;
        my $Value;
        if ( $Param{Frontend} eq 'Customer' ) {
            $Column = 'f_customer';
            $Value  = 1;
        }
        elsif ( $Param{Frontend} eq 'Agent' ) {
            $Column = 'f_agent';
            $Value  = 1;
        }
        $Value = $Self->{DBObject}->Quote( $Value, 'Integer' );
        if ( $SQL =~ m/WHERE/ ) {
            $SQL .= ' AND ' . $Column . ' = ' . $Value;
        }
        else {
            $SQL .= ' WHERE ' . $Column . ' = ' . $Value;
        }
    }

    return () if !$Self->{DBObject}->Prepare( SQL => $SQL );

    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $Templates{ $Row[0] } = $Row[1];
    }

    my $Config = $Self->{ConfigObject}->Get('Ticket::QuickTicketByDefaultSet::UserGroups');
    if ( $Param{UserID} ) {
        my $Permission = $Config->{Permission};

        if ( !$Param{Frontend} || $Param{Frontend} eq 'Agent' ) {
            $Self->{GroupObject} = $Kernel::OM->Get('Kernel::System::Group');
        }
        elsif ( $Param{Frontend} eq 'Customer' ) {
            $Self->{GroupObject} = $Kernel::OM->Get('Kernel::System::CustomerGroup');
        }
        my %UserGroups = $Self->{GroupObject}->GroupMemberList(
            UserID => $Param{UserID},
            Type   => $Permission,
            Result => 'HASH',
        );

        for my $Template ( keys %Templates ) {
            my $Found              = 0;
            my %TicketTemplateHash = $Self->TicketTemplateGet(
                ID => $Template
            );

            # no user groups defined for this ticket template
            next if !defined $TicketTemplateHash{UserGroupIDs};

            # get array of user groups with permission
            my @Array = split( /,/, $TicketTemplateHash{UserGroupIDs} );

            # check if user is part of one of these groups
            next if grep { defined $UserGroups{$_} } @Array;

            # delete if no permission
            delete( $Templates{$Template} );
        }
    }

    # set ticket template cache
    $Self->{$CacheKey} = {
        %Templates,
    };

    if ( defined $Param{Result} && $Param{Result} eq 'ID' ) {
        my @Templates = keys %Templates;
        return @Templates;
    }
    elsif ( defined $Param{Result} && $Param{Result} eq 'Name' ) {
        my @Templates = values %Templates;
        return @Templates;
    }
    else {
        return %Templates;
    }

}

=item TicketTemplateGet()

Returns data of one ticket template

    my %Hash = $TicketTemplateObject->TicketTemplateGet(
        ID  => 1
    );

    my %Hash = $TicketTemplateObject->TicketTemplateGet(
        Name  => 'TicketTemplateName'
    );

=cut

sub TicketTemplateGet {
    my ( $Self, %Param ) = @_;
    my %DynamicFields;

    # check needed stuff
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log( Priority => 'error', Message => "TicketTemplateGet: Need Name or ID!" );
        return;
    }

    # create YAML object
    my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

    # lookup ID if name given
    if ( !$Param{ID} ) {
        $Param{ID} = $Self->TicketTemplateLookup(
            Name => $Param{Name},
        );
    }
    else {
        $Param{Name} = $Self->TicketTemplateLookup(
            ID => $Param{ID},
        );
    }
    return () if !( $Param{ID} && $Param{Name} );

    # check if template is cached
    my $CacheKey = 'Cache::TicketTemplateGet::' . $Param{ID};
    if ( $Self->{$CacheKey} ) {
        return %{ $Self->{$CacheKey} };
    }

    # build ticket template data
    my %Template = (
        ID   => $Param{ID},
        Name => $Param{Name},
    );

    # get ticket template configuration
    return () if !$Self->{DBObject}->Prepare(
        SQL =>
            'SELECT preferences_key, preferences_value FROM kix_ticket_template_prefs WHERE template_id = ?',
        Bind => [ \$Param{ID} ],
    );
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {

        # special handling for dynamic fields
        if ( $Row[0] =~ /^DynamicField_/ ) {
            $Template{ $Row[0] } = $YAMLObject->Load( Data => $Row[1] );
        }
        else {
            $Template{ $Row[0] } = $Row[1];
        }
    }

    # get frontend template data
    return () if !$Self->{DBObject}->Prepare(
        SQL =>
            'SELECT f_agent, f_customer, customer_portal_group_id FROM kix_ticket_template WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $Template{Agent}    = $Row[0];
        $Template{Customer} = $Row[1];
        $Template{CustomerPortalGroupID} = $Row[2];
    }

    # set ticket template cache
    $Self->{$CacheKey} = {
        %Template,
    };

    return %Template;
}

=item TicketTemplateLookup()

Returns ID or name of a given ticket template

    my $Name = $TicketTemplateObject->TicketTemplateLookup(
        ID  => 1
    );

    my $ID = $TicketTemplateObject->TicketTemplateLookup(
        Name  => 'TicketTemplateName'
    );

=cut

sub TicketTemplateLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log( Priority => 'error', Message => "TicketTemplateLookup: Need Name or ID!" );
        return;
    }

    # create DB object
    $Self->{DBObject} = $Kernel::OM->Get('Kernel::System::DB');

    if ( $Param{ID} ) {

        # check cache
        my $CacheKey = 'Cache::TicketTemplateLookup::ID::' . $Param{ID};
        if ( defined $Self->{$CacheKey} ) {
            return $Self->{$CacheKey};
        }

        # lookup
        $Self->{DBObject}->Prepare(
            SQL   => 'SELECT name FROM kix_ticket_template WHERE id = ?',
            Bind  => [ \$Param{ID} ],
            Limit => 1,
        );
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            $Self->{$CacheKey} = $Row[0];
        }
        return $Self->{$CacheKey};
    }
    else {

        # check cache
        my $CacheKey = 'Cache::TicketTemplateLookup::Name::' . $Param{Name};
        if ( defined $Self->{$CacheKey} ) {
            return $Self->{$CacheKey};
        }

        # lookup
        $Self->{DBObject}->Prepare(
            SQL   => 'SELECT id FROM kix_ticket_template WHERE name = ?',
            Bind  => [ \$Param{Name} ],
            Limit => 1,
        );
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            $Self->{$CacheKey} = $Row[0];
        }
        return $Self->{$CacheKey};
    }
}

=item TicketTemplateCreate()

Creates a ticket template

    my $ID = $TicketTemplateObject->TicketTemplateCreate(
        Name    => 'TicketTemplateName',
        UserID  => 1,
        Data    => \%Hash
    );

=cut

sub TicketTemplateCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(UserID Name Data)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "TicketTemplateCreate: Need $Needed!" );
            return;
        }
    }

    # prepare CustomerPortalGroupID
    $Param{Data}->{CustomerPortalGroupID} ||= 0;

    # create YAML object
    my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

    my %Data = %{ $Param{Data} };

    # get template content
    my %Template = $Self->TicketTemplateGet(
        Name => $Param{Name},
    );

    # update action for existing templates
    if (%Template) {
        for my $Key ( keys %Data ) {

            # ignore empty and core preferences
            next
                if !$Key
                    || !defined $Data{$Key}
                    || $Data{$Key} eq ''
                    || $Key        eq 'DefaultSet'
                    || $Key        eq 'Name'
                    || $Key        eq 'ID';

            # handle for dynamic fields
            if ( ref $Data{$Key} eq 'HASH' ) {
                for my $HashKey ( keys %{ $Data{$Key} } ) {

                    # dump structures into a string to allow DFs with multiple values
                    my $Value = $YAMLObject->Dump( Data => $Data{$Key}->{$HashKey} );

                    # insert data
                    return if !$Self->{DBObject}->Do(
                        SQL =>
                            'UPDATE kix_ticket_template_prefs SET preferences_value = ? ' .
                            'WHERE preferences_key = ? AND template_id = ?',
                        Bind => [ \$Value, \$HashKey, \$Template{ID} ],
                    );
                }
            }
            else {

                # no update needed
                next if $Template{$Key} && $Template{$Key} eq $Data{$Key};

                # do update data
                return if !$Self->{DBObject}->Do(
                    SQL =>
                        'UPDATE kix_ticket_template_prefs SET preferences_value = ? ' .
                        'WHERE preferences_key = ? AND template_id = ?',
                    Bind => [ \$Data{$Key}, \$Key, \$Template{ID} ],
                );
            }
        }

        # do update meta data
        return if !$Self->{DBObject}->Do(
            SQL =>
                'UPDATE kix_ticket_template SET name = ?, f_agent = ?, f_customer = ?, customer_portal_group_id = ? ' .
                'WHERE id = ?',
            Bind => [ \$Data{Name}, \$Data{Agent}, \$Data{Customer}, \$Data{CustomerPortalGroupID}, \$Param{ID} ],
        );
    }

    # insert action
    else {
        return if !$Self->{DBObject}->Do(
            SQL => 'INSERT INTO kix_ticket_template '
                . '(name, valid_id, '
                . 'create_time, create_by, change_time, change_by, '
                . 'f_agent, f_customer, customer_portal_group_id) '
                . 'VALUES (?, 1, current_timestamp, ?, current_timestamp, ?, ?, ?, ?)',
            Bind => [
                \$Param{Name}, \$Param{UserID}, \$Param{UserID}, \$Data{Agent}, \$Data{Customer}, \$Data{CustomerPortalGroupID}
            ],
        );

        $Template{ID} = $Self->TicketTemplateLookup(
            Name => $Param{Name},
        );

        # set keys
        my %Data = %{ $Param{Data} };
        for my $Key ( keys %Data ) {

            # ignore empty and core preferences
            next
                if !$Key
                    || !defined $Data{$Key}
                    || $Data{$Key} eq ''
                    || $Key        eq 'DefaultSet'
                    || $Key        eq 'Name'
                    || $Key        eq 'ID';

            # handle for dynamic fields
            if ( ref $Data{$Key} eq 'HASH' ) {
                for my $HashKey ( keys %{ $Data{$Key} } ) {

                    # dump structures into a string to allow DFs with multiple values
                    my $Value = $YAMLObject->Dump( Data => $Data{$Key}->{$HashKey} );

                    # insert data
                    return if !$Self->{DBObject}->Do(
                        SQL =>
                            'INSERT INTO kix_ticket_template_prefs (template_id, preferences_key, preferences_value) '
                            . 'VALUES (?, ?, ?)',
                        Bind => [ \$Template{ID}, \$HashKey, \$Value ],
                    );
                }
            }

            else {

                # insert data
                return if !$Self->{DBObject}->Do(
                    SQL =>
                        'INSERT INTO kix_ticket_template_prefs (template_id, preferences_key, preferences_value) '
                        . 'VALUES (?, ?, ?)',
                    Bind => [ \$Template{ID}, \$Key, \$Data{$Key} ],
                );
            }

        }
    }

    # create ticket template cache
    %Template = $Self->TicketTemplateGet(
        Name => $Param{Name},
    );
    my $CacheKey = 'Cache::TicketTemplateGet::' . $Template{ID};
    $Self->{$CacheKey} = {
        %Template,
    };

    return $Template{ID};
}

=item TicketTemplateUpdate()

Updates ticket template data

    my $UpdateResult = $TicketTemplateObject->TicketTemplateUpdate(
        Name    => 'TicketTemplateName',
        UserID  => 1,
        Data    => \%Hash
    );

    my $UpdateResult = $TicketTemplateObject->TicketTemplateUpdate(
        ID      => 1,
        UserID  => 1,
        Data    => \%Hash
    );

=cut

sub TicketTemplateUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(UserID Data)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "TicketTemplateUpdate: Need $Needed!" );
            return;
        }
    }
    if ( ref $Param{Data} ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log(
            Priority => 'error',
            Message  => "TicketTemplateUpdate: Given data needs to be a hash element!"
            );
        return;
    }
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log( Priority => 'error', Message => "TicketTemplateUpdate: Need Name or ID!" );
        return;
    }

    # prepare CustomerPortalGroupID
    $Param{Data}->{CustomerPortalGroupID} ||= 0; 

    # create YAML object
    my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

    # get template content
    my %Template = $Self->TicketTemplateGet(
        ID   => $Param{ID}   || '',
        Name => $Param{Name} || '',
    );
    return if !%Template;

    # delete old template configuration
    return if !$Self->TicketTemplatePreferencesDelete(
        ID     => $Template{ID},
        UserID => $Param{UserID},
    );

    # update template
    my %Data = %{ $Param{Data} };
    for my $Key ( keys %Data ) {

        # ignore empty and core preferences
        next
            if !$Key
                || !defined $Data{$Key}
                || $Data{$Key} eq ''
                || $Key        eq 'DefaultSet'
                || $Key        eq 'Name'
                || $Key        eq 'ID';

        # handle for dynamic fields
        if ( ref $Data{$Key} eq 'HASH' ) {
            for my $HashKey ( keys %{ $Data{$Key} } ) {

                # dump structures into a string to allow DFs with multiple values
                my $Value = $YAMLObject->Dump( Data => $Data{$Key}->{$HashKey} );

                # insert data
                return if !$Self->{DBObject}->Do(
                    SQL =>
                        'INSERT INTO kix_ticket_template_prefs (template_id, preferences_key, preferences_value) '
                        . 'VALUES (?, ?, ?)',
                    Bind => [ \$Template{ID}, \$HashKey, \$Value ],
                );
            }
        }

        else {

            # insert data
            return if !$Self->{DBObject}->Do(
                SQL =>
                    'INSERT INTO kix_ticket_template_prefs (template_id, preferences_key, preferences_value) '
                    . 'VALUES (?, ?, ?)',
                Bind => [ \$Template{ID}, \$Key, \$Data{$Key} ],
            );
        }
    }

    #update meta data
    return if !$Self->{DBObject}->Do(
        SQL =>
            'UPDATE kix_ticket_template SET name = ?, f_agent = ?, f_customer = ?, customer_portal_group_id = ? ' .
            'WHERE id = ?',
        Bind => [ \$Data{Name}, \$Data{Agent}, \$Data{Customer}, \$Data{CustomerPortalGroupID}, \$Data{ID} ],
    );

    # clear ticket cache
    delete $Self->{ 'Cache::TicketTemplateGet::' . $Template{ID} };

    return 1;
}

=item TicketTemplatePreferencesDelete()

Deletes ticket template data

    my $DeleteResult = $TicketTemplateObject->TicketTemplatePreferencesDelete(
        Name    => 'TicketTemplateName',
        UserID  => 1,
    );

    my $DeleteResult = $TicketTemplateObject->TicketTemplatePreferencesDelete(
        ID      => 1,
        UserID  => 1,
    );

=cut

sub TicketTemplatePreferencesDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log(
                Priority => 'error',
                Message  => "TicketTemplatePreferencesDelete: Need $Needed!"
                );
            return;
        }
    }
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log(
            Priority => 'error',
            Message  => "TicketTemplatePreferencesDelete: Need Name or ID!"
            );
        return;
    }

    # get possible template content
    my %Template = $Self->TicketTemplateGet(
        ID   => $Param{ID}   || '',
        Name => $Param{Name} || '',
    );
    return if !%Template;

    # clear ticket template cache
    delete $Self->{ 'Cache::TicketTemplateGet::' . $Template{ID} };

    # delete ticket template preferences
    return if !$Self->{DBObject}->Do(
        SQL  => 'DELETE FROM kix_ticket_template_prefs WHERE template_id = ?',
        Bind => [ \$Template{ID} ],
    );

    return 1;
}

=item TicketTemplateDelete()

Deletes ticket template

    my $DeleteResult = $TicketTemplateObject->TicketTemplateDelete(
        Name    => 'TicketTemplateName',
        UserID  => 1,
    );

    my $DeleteResult = $TicketTemplateObject->TicketTemplateDelete(
        ID      => 1,
        UserID  => 1,
    );

=cut

sub TicketTemplateDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "TicketTemplateDelete: Need $Needed!" );
            return;
        }
    }
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log( Priority => 'error', Message => "TicketTemplateDelete: Need Name or ID!" );
        return;
    }

    # get possible template content
    my %Template = $Self->TicketTemplateGet(
        ID   => $Param{ID}   || '',
        Name => $Param{Name} || '',
    );
    return if !%Template;

    # clear ticket template cache
    delete $Self->{ 'Cache::TicketTemplateGet::' . $Template{ID} };
    delete $Self->{ 'Cache::TicketTemplateLookup::ID::' . $Template{ID} };
    delete $Self->{ 'Cache::TicketTemplateLookup::Name::' . $Template{Name} };
    delete $Self->{'Cache::TicketTemplateList'};

    # delete ticket template
    return if !$Self->TicketTemplatePreferencesDelete(
        ID     => $Template{ID},
        UserID => $Param{UserID},
    );
    return if !$Self->{DBObject}->Do(
        SQL  => 'DELETE FROM kix_ticket_template WHERE id = ?',
        Bind => [ \$Template{ID} ],
    );

    return 1;
}

=item TicketTemplateExport()

Exports ticket templates as XML file

    my $Result = $TicketTemplateObject->TicketTemplateExport(
    );

=cut

sub TicketTemplateExport {
    my ( $Self, %Param ) = @_;

    return $Self->_CreateTicketTemplateExportXML();
}

=item TicketTemplateImport()

Imports ticket templates as XML file

    my $Result = $TicketTemplateObject->TicketTemplateImport(
    );

=cut

sub TicketTemplateImport {
    my ( $Self, %Param ) = @_;

    return $Self->_ImportTicketTemplateXML(
        %Param,
        XMLString => $Param{Content},
    );
}

=item _ImportTicketTemplateXML()

Imports TicketTemplates from XML document.

    my $HashRef = $TicketTemplateObject->_ImportTicketTemplateXML(
        XMLString => '<xml><tag>...</tag>', #required
        DoNotAdd => 0|1, #DO NOT create new entry if no existing id given
        UserID   => 123, #required
    );

=cut

sub _ImportTicketTemplateXML {
    my ( $Self, %Param ) = @_;
    my %Result = ();

    $Self->{XMLObject} = $Kernel::OM->Get('Kernel::System::XML');

    #init counters...
    $Result{CountUploaded}     = 0;
    $Result{CountInsertFailed} = 0;
    $Result{CountAdded}        = 0;
    $Result{UploadMessage}     = '';

    # check required params...
    for (qw( XMLString UserID )) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my @XMLHash = $Self->{XMLObject}->XMLParse2XMLHash(
        String => $Param{XMLString}
    );

    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my @UpdateArray;

    if (
        $XMLHash[1]
        &&
        ref( $XMLHash[1] ) eq 'HASH'
        && $XMLHash[1]->{'TicketTemplateList'}
        && ref( $XMLHash[1]->{'TicketTemplateList'} ) eq 'ARRAY'
        && $XMLHash[1]->{'TicketTemplateList'}->[1]
        && ref( $XMLHash[1]->{'TicketTemplateList'}->[1] ) eq 'HASH'
        && $XMLHash[1]->{'TicketTemplateList'}->[1]->{'TicketTemplateEntry'}
        && ref( $XMLHash[1]->{'TicketTemplateList'}->[1]->{'TicketTemplateEntry'} ) eq 'ARRAY'
        )
    {
        my $TMArrIndex = 0;
        for my $TMArrRef ( @{ $XMLHash[1]->{'TicketTemplateList'}->[1]->{'TicketTemplateEntry'} } )
        {
            next if ( !defined($TMArrRef) || ref($TMArrRef) ne 'HASH' );

            $TMArrIndex++;
            my %UpdateData = ();
            for my $Key ( %{$TMArrRef} ) {
                if (
                    ref( $TMArrRef->{$Key} ) eq 'ARRAY'
                    && $TMArrRef->{$Key}->[1]
                    && ref( $TMArrRef->{$Key}->[1] ) eq 'HASH'
                    )
                {
                    next if !$TMArrRef->{$Key}->[1]->{Content};

                    if ( $Key eq 'Queue' ) {
                        $UpdateData{QueueID}
                            = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
                            Queue => $TMArrRef->{$Key}->[1]->{Content}
                            );
                    }
                    elsif ( $Key eq 'Type' ) {
                        $UpdateData{TypeID} = $Kernel::OM->Get('Kernel::System::Type')->TypeLookup(
                            Type => $TMArrRef->{$Key}->[1]->{Content}
                        );
                    }
                    elsif ( $Key eq 'State' ) {
                        $UpdateData{StateID}
                            = $Kernel::OM->Get('Kernel::System::State')->StateLookup(
                            State => $TMArrRef->{$Key}->[1]->{Content}
                            );
                    }
                    elsif ( $Key eq 'Priority' ) {
                        $UpdateData{PriorityID}
                            = $Kernel::OM->Get('Kernel::System::Priority')->PriorityLookup(
                            Priority => $TMArrRef->{$Key}->[1]->{Content}
                            );
                    }
                    elsif ( ( $Key eq 'Owner' || $Key eq 'Responsible' ) ) {
                        $UpdateData{ $Key . 'ID' }
                            = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
                            UserLogin => $TMArrRef->{$Key}->[1]->{Content}
                            );
                    }
                    elsif ( $Key eq 'Service' ) {
                        $UpdateData{ServiceID}
                            = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
                            Name => $TMArrRef->{$Key}->[1]->{Content}
                            );
                    }
                    elsif ( $Key eq 'SLA' ) {
                        $UpdateData{SLAID} = $Kernel::OM->Get('Kernel::System::SLA')->SLALookup(
                            Name => $TMArrRef->{$Key}->[1]->{Content}
                        );
                    }
                    elsif ( $Key =~ m/^DynamicField_(.*)/ ) {
                        my $FieldName = $1;
                        next if ( !defined $1 || !$1 );

                        # get the dynamic field
                        my $DynamicField = $DynamicFieldObject->DynamicFieldGet(
                            Name => $FieldName,
                        );

                        # handling for multiselect fields
                        if (
                            (
                                defined $DynamicField->{FieldType}
                                && $DynamicField->{FieldType}
                                =~ /^(Multiselect|MultiselectGeneralCatalog)$/
                            )
                            || (
                                defined $DynamicField->{Config}->{DisplayFieldType}
                                && $DynamicField->{Config}->{DisplayFieldType} eq 'Multiselect'
                            )
                            )
                        {
                            for my $Item ( @{ $TMArrRef->{$Key} } ) {
                                next if ref $Item ne 'HASH';
                                push @{ $UpdateData{DynamicField}->{$Key} }, $Item->{Content};
                            }
                        }
                        else {
                            $UpdateData{DynamicField}->{$Key} = $TMArrRef->{$Key}->[1]->{Content}
                        }
                    }
                    else {
                        $UpdateData{$Key} = $TMArrRef->{$Key}->[1]->{Content} || '';
                    }

                }
            }

            $Result{CountUploaded}++;

            my $UpdateResult = 0;
            my $ErrorMessage = "";
            my $Status       = "";

            # insert ticket template
            $UpdateData{ID} = $Self->TicketTemplateCreate(
                Data   => \%UpdateData,
                UserID => $Param{UserID},
                Name   => $UpdateData{Name},
            );

            if ( $UpdateData{ID} ) {
                $Result{CountAdded}++;
                $Status = 'Insert OK';
            }
            else {
                $Result{CountInsertFailed}++;
                $Status = 'Insert Failed';
            }

        }
    }

    $Result{XMLResultString} = $Self->{XMLObject}->XMLHash2XML(@XMLHash);

    return \%Result;
}

=item _CreateTicketTemplateExportXML()

Exports all TicketTemplates into XML document.

    my $String = $TicketTemplateObject->_CreateTicketTemplateExportXML();

=cut

sub _CreateTicketTemplateExportXML {
    my ( $Self, %Param ) = @_;
    my $Result = "";

    $Self->{XMLObject} = $Kernel::OM->Get('Kernel::System::XML');

    my %TicketTemplateData = $Self->TicketTemplateList(%Param);
    my @ExportDataArray;
    push( @ExportDataArray, undef );

    for my $CurrHashID ( sort keys %TicketTemplateData ) {

        my %TicketTemplate = $Self->TicketTemplateGet(
            ID => $CurrHashID,
        );

        my %CurrTM = ();
        for my $CurrKey ( sort keys(%TicketTemplate) ) {

            $CurrTM{$CurrKey}->[0] = undef;

            if ( $CurrKey eq 'QueueID' && $TicketTemplate{$CurrKey} ne '-' ) {
                $CurrTM{Queue}->[1]->{Content}
                    = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
                    QueueID => $TicketTemplate{$CurrKey}
                    );
            }
            elsif ( $CurrKey eq 'TypeID' ) {
                $CurrTM{Type}->[1]->{Content}
                    = $Kernel::OM->Get('Kernel::System::Type')->TypeLookup(
                    TypeID => $TicketTemplate{$CurrKey}
                    );
            }
            elsif ( $CurrKey eq 'StateID' ) {
                $CurrTM{State}->[1]->{Content}
                    = $Kernel::OM->Get('Kernel::System::State')->StateLookup(
                    StateID => $TicketTemplate{$CurrKey}
                    );
            }
            elsif ( $CurrKey eq 'PriorityID' ) {
                $CurrTM{Priority}->[1]->{Content}
                    = $Kernel::OM->Get('Kernel::System::Priority')->PriorityLookup(
                    PriorityID => $TicketTemplate{$CurrKey}
                    );
            }
            elsif ( $CurrKey eq 'OwnerID' || $CurrKey eq 'ResponsibleID' ) {
                $CurrTM{ substr( $CurrKey, 0, -2 ) }->[1]->{Content}
                    = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
                    UserID => $TicketTemplate{$CurrKey}
                    );
            }
            elsif ( $CurrKey eq 'ServiceID' ) {
                $CurrTM{Service}->[1]->{Content}
                    = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
                    ServiceID => $TicketTemplate{$CurrKey}
                    );
            }
            elsif ( $CurrKey eq 'SLAID' ) {
                $CurrTM{SLA}->[1]->{Content}
                    = $Kernel::OM->Get('Kernel::System::SLA')->SLALookup(
                    SLAID => $TicketTemplate{$CurrKey}
                    );
            }
            elsif ( $CurrKey =~ m/^DynamicField_.*/ ) {
                if ( ref $TicketTemplate{$CurrKey} ne 'ARRAY' ) {
                    $CurrTM{$CurrKey}->[1]->{Content}
                        = $TicketTemplate{$CurrKey};
                }
                else {
                    for my $Item ( @{ $TicketTemplate{$CurrKey} } ) {
                        my %TmpHash = ( Content => $Item );
                        push @{ $CurrTM{$CurrKey} }, \%TmpHash;
                    }
                }
            }
            else {
                $CurrTM{$CurrKey}->[1]->{Content} = $TicketTemplate{$CurrKey};
            }

        }

        # export *-lists...
        push( @ExportDataArray, \%CurrTM );

    }

    my @XMLHashArray;
    push( @XMLHashArray, undef );

    my %XMLHashTicketTemplate = ();
    $XMLHashTicketTemplate{'TicketTemplateList'}->[0] = undef;
    $XMLHashTicketTemplate{'TicketTemplateList'}->[1]->{'TicketTemplateEntry'}
        = \@ExportDataArray;

    push( @XMLHashArray, \%XMLHashTicketTemplate );

    $Result = $Self->{XMLObject}->XMLHash2XML(@XMLHashArray);

    return $Result;
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
