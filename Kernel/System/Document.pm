# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Document;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Document

=head1 SYNOPSIS

Document backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a Document object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $DocumentObject = $Kernel::OM->Get('Kernel::System::DocumentField');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{MainObject}   = $Kernel::OM->Get('Kernel::System::Main');

    $Self->{Config} = $Self->{ConfigObject}->Get('Document');

    return $Self;
}

=item DocumentGet()

    my %Data = $DocumentObject->DocumentGet(
        DocumentID  => $DocumentID,
    );

=cut

sub DocumentGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(DocumentID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "DocumentGet: Need $Argument!",
            );
            return;
        }
    }

    return if $Param{DocumentID} !~ /^(.+):(.+)$/;

    $Param{DocumentBackendID} = $1;
    $Param{DocumentID}        = $2;

    my $BackendObject = $Self->_LoadBackend(
        Backend => $Param{DocumentBackendID}
    );
    return if !$BackendObject;

    return $BackendObject->DocumentGet(%Param);
}

=item DocumentMetaGet()

    my %Data = $DocumentObject->DocumentMetaGet(
        DocumentID  => $DocumentID,
    );

=cut

sub DocumentMetaGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(DocumentID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "DocumentMetaGet: Need $Argument!",
            );
            return;
        }
    }

    return if $Param{DocumentID} !~ /^(.+):(.+)$/;

    $Param{DocumentBackendID} = $1;
    $Param{DocumentID}        = $2;

    my $BackendObject = $Self->_LoadBackend(
        Backend => $Param{DocumentBackendID}
    );
    return if !$BackendObject;

    return $BackendObject->DocumentMetaGet(%Param);
}

=item DocumentLinkGet()

    my %Data = $DocumentObject->DocumentLinkGet(
        DocumentID  => $DocumentID,
    );

=cut

sub DocumentLinkGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(DocumentID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "DocumentLinkGet: Need $Argument!",
            );
            return;
        }
    }

    return if $Param{DocumentID} !~ /^(.+):(.+)$/;

    $Param{DocumentBackendID} = $1;
    $Param{DocumentID}        = $2;

    my $BackendObject = $Self->_LoadBackend(
        Backend => $Param{DocumentBackendID}
    );
    return if !$BackendObject;

    my $Permission = $BackendObject->DocumentCheckPermission(
        DocumentID => $Param{DocumentID},
        UserID     => $Param{UserID}
    );
    my %LinkData;
    if ( $Permission eq 'Access' ) {
        $LinkData{URL}
            = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{Baselink} . 'Action=AgentLinkObjectUtils;Subaction=DownloadDocument;DocumentID='
            . $Param{DocumentBackendID} . ':'
            . $Param{DocumentID};
    }
    else {
        $LinkData{LinkInfo} = $Permission;
    }

    return %LinkData;
}

=item DocumentNameSearch()

    my @SearchList = $DocumentObject->DocumentNameSearch(
        UserID      => $UserID,
        Source      => $Source,
        FileName    => $FileName,
        Limit       => $Limit,
    );

=cut

sub DocumentNameSearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(UserID Source FileName Limit)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "DocumentNameSearch: Need $Argument!",
            );
            return;
        }
    }

    my $BackendObject = $Self->_LoadBackend(
        Backend => $Self->{Config}->{Backend}->{ $Param{Source} }
    );
    return if !$BackendObject;

    my @SearchList = $BackendObject->DocumentNameSearch(%Param);
    @SearchList =
        map ( { $Self->{Config}->{Backend}->{ $Param{Source} } . ':' . $_ } @SearchList );

    return @SearchList;
}

=item DocumentCheckPermission()

    my $Result = $DocumentObject->DocumentCheckPermission(
        DocumentID  => $DocumentID,
    );

=cut

sub DocumentCheckPermission {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(DocumentID)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "DocumentCheckPermission: Need $Argument!",
            );
            return;
        }
    }

    return if $Param{DocumentID} !~ /^(.+):(.+)$/;

    $Param{DocumentBackendID} = $1;
    $Param{DocumentID}        = $2;

    my $BackendObject = $Self->_LoadBackend(
        Backend => $Param{DocumentBackendID}
    );
    return if !$BackendObject;

    return $BackendObject->DocumentCheckPermission(
        DocumentID => $Param{DocumentID},
        UserID     => $Param{UserID}
    );
}

=item _LoadBackend()

    my $BackendObject = $DocumentObject->_LoadBackend(
        Backend => $Backend,
    );

=cut

sub _LoadBackend {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Backend)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "_LoadBackend: Need $Argument!",
            );
            return;
        }
    }

    # check if object is already cached
    return $Self->{Cache}->{LoadBackend}->{ $Param{Backend} }
        if $Self->{Cache}->{LoadBackend}->{ $Param{Backend} };

    my $BackendModule = "Kernel::System::Document::$Param{Backend}";

    # load the backend module
    if ( !$Self->{MainObject}->Require($BackendModule) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Can't load document backend module $Param{Backend}!"
        );
        return;
    }

    # create new instance
    my $BackendObject = $BackendModule->new(
        %{$Self},
        %Param,
        LinkObject => $Self,
    );

    if ( !$BackendObject ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "_LoadBackend: Can't load link backend module '$Param{Backend}'!",
        );
        return;
    }

    # cache the object
    $Self->{Cache}->{LoadBackend}->{ $Param{Backend} } = $BackendObject;

    return $BackendObject;
}

=item DocumentSourcesList()

    my %SourcesList = $DocumentObject->DocumentSourcesList(
        UserID      => $UserID,
    );

=cut

sub DocumentSourcesList {
    my ( $Self, %Param ) = @_;

    my $Config          = $Self->{ConfigObject}->Get('Document');
    my $DocumentSource  = $Config->{Sources};
    my $DocumentBackend = $Config->{Backend};

    my %SourcesList;
    my %BackendObjects;
    for my $Source ( keys %{$DocumentSource} ) {
        my $Backend = $DocumentBackend->{$Source};
        if ( !$BackendObjects{$Backend} ) {
            $BackendObjects{$Backend} = $Self->_LoadBackend(
                Backend => $Backend,
            );
        }

        if ( $BackendObjects{$Backend} ) {
            my $Result = $BackendObjects{$Backend}->DocumentCheckSourceAccess(
                Source => $Source,
                UserID => $Param{UserID}
            );
            if ($Result) {
                $SourcesList{$Source} = $DocumentSource->{$Source};
            }
        }
    }

    return %SourcesList;
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
