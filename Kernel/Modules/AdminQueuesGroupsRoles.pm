# --
# Kernel/Modules/AdminQueuesGroupsRoles.pm - admin frontend to manage queues,
# groups and roles
# Copyright (C) 2006-2015 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Stefan(dot)Mehlig(at)cape(dash)it.de
# * Anna(dot)Litvinova(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Frank(dot)Oberender(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminQueuesGroupsRoles;

use strict;
use warnings;

use File::Temp qw( tempfile tempdir );
use File::Basename;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::QueuesGroupsRoles',    
    'Kernel::System::Group',
    'Kernel::System::Config',
    'Kernel::System::Web::UploadCache',
    'Kernel::System::Web::Request',
    'Kernel::System::Queue',
    'Kernel::System::SystemAddress',
    'Kernel::System::Time',
);

use vars qw($VERSION);
$VERSION = qw($Revision$) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $QGRObject    = $Kernel::OM->Get('Kernel::System::QueuesGroupsRoles');
    my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');
    
    my $Config = $Kernel::OM->Get('Kernel::Config')->Get("QueuesGroupsRoles");
 
    # create form id
    my $FormID = $Kernel::OM->Get('Kernel::System::Web::UploadCache')->FormIDCreate();


    # get params
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my @Frontends = $ParamObject->GetArray( Param => 'Frontend' );
    my %GetParam = map { $_ => 1 } @Frontends;
    for (
        qw(ID Name Keywords Comment Comment1 Comment2 Subject TextModule
        Language LanguageEdit ValidID FormID Limit Show Download
        XMLUploadDoNotAdd XMLResultFileID XMLResultFileName)
        )
    {
        $GetParam{$_} = $ParamObject->GetParam( Param => $_ ) || '';
    }
    # build queue selection
    $Param{FormID} = $FormID;

    # ------------------------------------------------------------------------ #
    # upload
    # ------------------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Upload' && $GetParam{FormID} ) {

        # get uploaded data...
        my %UploadStuff = $ParamObject->GetUploadAll(
            Param  => 'file_upload',
            Source => 'string',
        );

        #my @Content = ();
        if ($UploadStuff{Content}) {
            my @Content = split( /\n/, $UploadStuff{Content} );
            $QGRObject->Upload( Content => \@Content );
        }

        #if (@Content) {
            #$QGRObject->Upload( Content => \@Content );
        #}
    }

    # ------------------------------------------------------------ #
    # show overview
    # ------------------------------------------------------------ #

    my @Result = $QGRObject->QGRShow();

    my @Head = @{ $Result[0] };
    my @Data = @{ $Result[1] };

    my %ShortcutMappings;
    if ( $Config
         && ref($Config) eq 'HASH'
         && $Config->{ShortcutMappings}
         && ref($Config->{ShortcutMappings}) eq 'HASH'
         && $Config->{ShortcutMappings}->{'rw'}
    ) {
        %ShortcutMappings = %{$Config->{ShortcutMappings}};
    } 

    if ( $Self->{Subaction} eq 'Show' ) {

        # create output for overview
        my $HeaderLink;
        for my $Head (@Head) {
            my $ID;
            my $Link;

            if ($HeaderLink) {
                $ID = $GroupObject->RoleLookup( Role => $Head );
                $Link = 'Action=AdminRoleUser;Subaction=Role;ID=' . $ID;
            }

            if ( !$HeaderLink ) {

                # output table header
                $LayoutObject->Block(
                    Name => 'TableHeader',
                    Data => {
                        Header => $Head,
                        }

                );
            }
            else {

                # output table header
                $LayoutObject->Block(
                    Name => 'TableHeaderLink',
                    Data => {
                        Header => $Head,
                        Link   => $Link,
                        }
                );
            }
            if ( $Head eq 'SystemAddress' ) {
                $HeaderLink = 1;
            }
        }

        for my $DataRow (@Data) {

            # output table body
            $LayoutObject->Block(
                Name => 'TableBodyRow',
            );
            for my $Data ( @{$DataRow} ) {
                my $ID;
                my $Link;
                my $Link2;
                if ( !$Data ) {
                }
                elsif ( $Data eq ${$DataRow}[0] ) {
                    $ID = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup( Queue => ${$DataRow}[0] );
                    $Link = 'Action=AdminQueue;Subaction=Change;QueueID=' . $ID;
                }
                elsif ( $Data eq ${$DataRow}[1] ) {
                    $ID = $GroupObject->GroupLookup( Group => $Data );
                    $Link = 'Action=AdminUserGroup;Subaction=Group;ID=' . $ID;
                }
                elsif ( $Data eq ${$DataRow}[15] ) {
                    my %List    = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressList();
                    for my $CurrKey ( keys(%List) ) {
                        if ( $Data =~ /.*<?$List{$CurrKey}>?/ ) {
                            $ID = $CurrKey;
                            last;
                        }
                    }
                    $Link = 'Action=AdminSystemAddress;Subaction=Change;ID=' . $ID;
                }
                elsif ( %ShortcutMappings )
                {
                    my $ExistingPermission = 0;
                    for my $ShortCutMaping (keys %ShortcutMappings) {
                        if ($Data !~ /\d/ && $Data !~ /valid/) {
                            $Data =~ s/$ShortCutMaping/$ShortcutMappings{$ShortCutMaping}/g;
                            $ExistingPermission++;
                        }
                    }
                    if ($ExistingPermission) {
                        $ID = $GroupObject->GroupLookup( Group => ${$DataRow}[1] );
                        $Link = 'Action=AdminRoleGroup;Subaction=Group;ID=' . $ID;
                    }
                    else {
                        $Link = '';
                    }
                }
                elsif (
                    $Data    =~ /ro/
                    || $Data =~ /move_into/
                    || $Data =~ /create/
                    || $Data =~ /note/
                    || $Data =~ /owner/
                    || $Data =~ /priority/ 
                    || $Data =~ /rw/
                    )
                {
                    $ID = $GroupObject->GroupLookup( Group => ${$DataRow}[1] );
                    $Link = 'Action=AdminRoleGroup;Subaction=Group;ID=' . $ID;
                }
                $LayoutObject->Block(
                    Name => 'TableBodyContent',
                    Data => {
                        Content => $Data,
                        }
                );
                if ($Link) {

                    # output table body
                    $LayoutObject->Block(
                        Name => 'TableBodyContentLinkStart',
                        Data => {
                            Content => $Data,
                            Link    => $Link,
                            }
                    );

                    # output table body
                    $LayoutObject->Block(
                        Name => 'TableBodyContentLinkEnd',
                    );
                }
            }
        }
    }

    # ------------------------------------------------------------ #
    # Download CSV
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Download' ) {

        my $Result = $QGRObject->Download(
            Head => \@Head,
            Data => \@Data,
        );

        my $TimeString = $Kernel::OM->Get('Kernel::System::Time')->SystemTime2TimeStamp(
            SystemTime => $Kernel::OM->Get('Kernel::System::Time')->SystemTime(),
        );
        $TimeString =~ s/\s/\_/g;
        my $FileName = 'QueuesGroupsRoles_' . $TimeString . '.csv';

        return $LayoutObject->Attachment(
            Type        => 'attachment',
            Filename    => $FileName,
            ContentType => 'text/csv',
            Content     => $Result,
            NoCache     => 1,
        );
    }

    # ------------------------------------------------------------ #
    # overview
    # ------------------------------------------------------------ #

    # output header
    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    # output show
    $LayoutObject->Block(
        Name => 'Show',
        Data => \%Param,
    );

    # output download
    $LayoutObject->Block(
        Name => 'Download',
        Data => \%Param,
    );

    # output upload
    $LayoutObject->Block(
        Name => 'Upload',
        Data => \%Param,
    );

    # generate output
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminQueuesGroupsRoles',
        Data         => \%Param,
    );

    $Output .= $LayoutObject->Footer();

    return $Output;
}

1;
