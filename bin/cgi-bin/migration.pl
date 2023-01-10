#!/usr/bin/perl
# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

# use ../../ as lib location
use FindBin qw($Bin);
use lib "$Bin/../..";
use lib "$Bin/../../Kernel/cpan-lib";
use lib "$Bin/../../Custom";

use MIME::Base64;

# 0=off;1=on;
my $Debug = 0;

# load public interface
use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

local $Kernel::OM = Kernel::System::ObjectManager->new();

my $ConfigObject  = $Kernel::OM->Get('Kernel::Config')               || die 'Got no ConfigObject!';
my $DBObject      = $Kernel::OM->Get('Kernel::System::DB')           || die 'Got no DBObject!';
my $JSONObject    = $Kernel::OM->Get('Kernel::System::JSON')         || die 'Got no JSONObject!';
my $RequestObject = $Kernel::OM->Get('Kernel::System::Web::Request') || die 'Got no RequestObject!';

# check for activated migration endpoint
my $Active = $ConfigObject->Get('Migration::Active');
if (
    !$Active
    || $Active ne '1'
) {
    print "Status: 403 Forbidden\n\n";
    exit 0;
}

# define special handling
my %Special = (
    'configitem_xmldata'    => \&_GetConfigItemXMLData,
    'configitem_attachment' => \&_GetConfigItemAttachments,
    'article_attachment'    => \&_GetArticleAttachments,
    'article_plain'         => \&_GetArticlePlain,
    'faq_attachment'        => \&_GetFAQAttachments,
);

# get all table names from DB
$DBObject->Connect() || die "Unable to connect to database!";
my %Tables = map { my $Table = (split(/\./, $_))[1]; $Table =~ s/\`//g; $Table => 1 } $DBObject->{dbh}->tables('', $DBObject->{'DB::Type'} eq 'postgresql' ? 'public' : '', '', 'TABLE');

my $HTTPResponse = "Status: 200 OK\nContent-Type: application/json\n\n";
my $Output;

my $PSK        = $RequestObject->GetParam(Param => 'PSK');
my $ObjectType = $RequestObject->GetParam(Param => 'Type');
my $ObjectID   = $RequestObject->GetParam(Param => 'ObjectID');
my $Result     = $RequestObject->GetParam(Param => 'Result');
my $OrderBy    = $RequestObject->GetParam(Param => 'OrderBy');
my $Where      = $RequestObject->GetParam(Param => 'Where');
my $What       = $RequestObject->GetParam(Param => 'What');
my $Limit      = $RequestObject->GetParam(Param => 'Limit');

my $ConfiguredPSK = $ConfigObject->Get('Migration::PSK');

if ( $ConfiguredPSK && $ConfiguredPSK ne $PSK ) {
    print "Status: 401 Unauthorized\n\n";
    exit 0;
}

if ( $Result && $Result eq 'COUNT' ) {
    $Output = _Count(
        Tables     => \%Tables,
        ObjectType => $ObjectType,
        Where      => $Where,
    );
}
elsif ( !$ObjectType ) {
    $Output = [ sort keys %Tables ]
}
elsif ( $Special{$ObjectType} ) {
    $Output = $Special{$ObjectType}->(
        ObjectType => $ObjectType,
        ObjectID   => $ObjectID,
    );
}
elsif ( $Tables{$ObjectType} ) {
    $Output = _GetData(
        ObjectType => $ObjectType,
        What       => $What,
        Where      => $Where,
        Limit      => $Limit,
        OrderBy    => $OrderBy,
    );
}
else {
    $HTTPResponse = "Status: 404 Not Found\n";
}

print $HTTPResponse."\n";
if ( $Output ) {
    print $JSONObject->Encode(
        Data => $Output
    );
}

sub _Count {
    my %Param = @_;

    my @ObjectTypes = $Param{ObjectType} ? ( $Param{ObjectType} ) : sort keys %{$Param{Tables}};

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my %Data;
    foreach my $ObjectType ( @ObjectTypes ) {
        my $SQL = "SELECT COUNT(*) FROM $ObjectType";
        if ( $Param{Where} ) {
            $SQL .= ' WHERE ' . $Param{Where};
        }

        $DBObject->Prepare(
            SQL   => $SQL,
        ) || die "Unable to execute SQL statement!";

        while (my @Row = $DBObject->FetchrowArray()) {
            $Data{$ObjectType} = $Row[0];
        }
    }
    return \%Data;
}

sub _GetData {
    my %Param = @_;
    my $SQL = $Param{SQL};

    my $What = $Param{What} || '*';

    if ( !$SQL ) {
        $SQL = "SELECT $What FROM $Param{ObjectType}";
        if ( $Param{Where} ) {
            $SQL .= ' WHERE ' . $Param{Where};
        }
        if ( $Param{OrderBy} ) {
            $SQL .= ' ORDER BY ' . $Param{OrderBy};
        }
        if ( $Param{Limit} ) {
            $SQL .= ' LIMIT ' . $Param{Limit};
        }
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

   # get data from table
    $DBObject->Prepare(
        SQL => $SQL,
    ) || die "Unable to execute SQL statement!";

    my @Names = $DBObject->GetColumnNames();
    my @Data;
    while (my @Row = $DBObject->FetchrowArray()) {
        my %Item;
        my $ColID = 0;
        foreach my $Col ( @Names ) {
            $Item{$Col} = $Row[$ColID++];
        }
        push @Data, \%Item;
    }
    return \@Data;
}

sub _GetConfigItemAttachments {
    my %Param = @_;
    my @Data;

    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    my @Attachments = $ConfigItemObject->ConfigItemAttachmentList(
        ConfigItemID => $Param{ObjectID},
    );

    for my $Attachment (@Attachments) {
        # get the metadata of the current attachment
        my $Attachment = $ConfigItemObject->ConfigItemAttachmentGet(
            ConfigItemID => $Param{ObjectID},
            Filename     => $Attachment,
        );

        $Attachment->{Content} = MIME::Base64::encode_base64($Attachment->{Content});

        push @Data, $Attachment;
    }

    return \@Data;
}

sub _GetConfigItemXMLData {
    my %Param = @_;
    my @Data;

    # check if KIXPro is installed
    my $KIXProInstalled = $Kernel::OM->Get('Kernel::System::Package')->PackageIsInstalled(
        Name   => 'KIXPro',
    );
    if ( !$KIXProInstalled ) {
        # get the data from xml_storage
        return _GetData(
            ObjectType => 'xml_storage',
            Where      => 'xml_key = \'' . $Param{ObjectID} . '\' AND xml_type LIKE \'ITSM::ConfigItem::%\'',
            OrderBy    => 'xml_key',
        );
    }

    # handle KIXPro
    my @ClassIDs = keys %{$Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    ) || {}};

    my @Parts;
    foreach my $ClassID ( @ClassIDs ) {
        my $Definitions = _GetData(
            ObjectType => 'configitem_definition',
            Where      => "class_id = $ClassID",
            Limit      => 1,
        );
        next if !IsArrayRefWithData($Definitions);

        push @Parts, "SELECT 'ITSM::ConfigItem::" . $ClassID . "' as xml_type, xml_key, xml_content_key, xml_content_value from v_ci_" . $ClassID;
        push @Parts, "SELECT 'ITSM::ConfigItem::Archiv::" . $ClassID . "' as xml_type, xml_key, xml_content_key, xml_content_value from v_ci_" . $ClassID . '_archive';
    }

    if ( $Param{ObjectID} ) {
        foreach my $Part ( @Parts ) {
            $Part .= " WHERE xml_key = '$Param{ObjectID}'";
        }
    }

    my $SQL = join(' UNION ', @Parts);

    return _GetData(
        SQL => $SQL
    );
}

sub _GetArticleAttachments {
    my %Param = @_;
    my @Data;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    $TicketObject->{CheckAllBackends} = 1;

    my %Attachments = $TicketObject->ArticleAttachmentIndexRaw(
        ArticleID => $Param{ObjectID},
        UserID    => 1,
    );

    for my $FileID (sort keys %Attachments) {
        my %Attachment = $TicketObject->ArticleAttachment(
            ArticleID => $Param{ObjectID},
            FileID    => $FileID,
            UserID    => 1,
        );

        $Attachment{Content} = MIME::Base64::encode_base64($Attachment{Content});

        push @Data, \%Attachment;
    }

    return \@Data;
}

sub _GetArticlePlain {
    my %Param = @_;
    my %Result;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    $TicketObject->{CheckAllBackends} = 1;

    my $PlainBody = $TicketObject->ArticlePlain(
        ArticleID => $Param{ObjectID},
        UserID    => 1,
    );

    if ( $PlainBody ) {
        $PlainBody = MIME::Base64::encode_base64($PlainBody);

        %Result = (
            Content => $PlainBody
        );
    }

    return \%Result;
}

sub _GetFAQAttachments {
    my %Param = @_;

    my $Data = _GetData(
        ObjectType => $Param{ObjectType},
        Where      => 'faq_id = ' . $Param{ObjectID},
    );

    if ( IsArrayRefWithData($Data) && $Kernel::OM->Get('Kernel::System::DB')->GetDatabaseFunction('DirectBlob') ) {
        # encode content to base64
        foreach my $Item (@{$Data}) {
            $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput(\$Item->{content});
            $Item->{content} = MIME::Base64::encode_base64($Item->{content});
        }
    }

    return $Data;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
