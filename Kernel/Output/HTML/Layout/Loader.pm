# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# KIXCore-Extensions Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# * Anna(dot)Litvinova(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::Loader;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

# KIXCore-capeIT
use File::Copy;
use File::Path qw(mkpath);

# EO KIXCore-capeIT

=head1 NAME

Kernel::Output::HTML::Layout::Loader - CSS/JavaScript

=head1 SYNOPSIS

All valid functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item LoaderCreateAgentCSSCalls()

Generate the minified CSS files and the tags referencing them,
taking a list from the Loader::Agent::CommonCSS config item.

    $LayoutObject->LoaderCreateAgentCSSCalls(
        Skin => 'MySkin', # optional, if not provided skin is the configured by default
    );

=cut

sub LoaderCreateAgentCSSCalls {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get host based default skin configuration
    my $SkinSelectedHostBased;
    my $DefaultSkinHostBased = $ConfigObject->Get('Loader::Agent::DefaultSelectedSkin::HostBased');
    if ( $DefaultSkinHostBased && $ENV{HTTP_HOST} ) {
        REGEXP:
        for my $RegExp ( sort keys %{$DefaultSkinHostBased} ) {

            # do not use empty regexp or skin directories
            next REGEXP if !$RegExp;
            next REGEXP if !$DefaultSkinHostBased->{$RegExp};

            # check if regexp is matching
            if ( $ENV{HTTP_HOST} =~ /$RegExp/i ) {
                $SkinSelectedHostBased = $DefaultSkinHostBased->{$RegExp};
            }
        }
    }

    # determine skin
    # 1. use UserSkin setting from Agent preferences, if available
    # 2. use HostBased skin setting, if available
    # 3. use default skin from configuration

    my $SkinSelected = $Self->{'UserSkin'};

    # check if the skin is valid
    my $SkinValid = 0;
    if ($SkinSelected) {
        $SkinValid = $Self->SkinValidate(
            SkinType => 'Agent',
            Skin     => $SkinSelected,
        );
    }

    if ( !$SkinValid ) {
        $SkinSelected = $SkinSelectedHostBased
            || $ConfigObject->Get('Loader::Agent::DefaultSelectedSkin')
            || 'default';
    }

    # save selected skin
    $Self->{SkinSelected} = $SkinSelected;

    my $SkinHome = $ConfigObject->Get('Home') . '/var/httpd/htdocs/skins';
    my $DoMinify = $ConfigObject->Get('Loader::Enabled::CSS');

    my $ToolbarModuleSettings    = $ConfigObject->Get('Frontend::ToolBarModule');
    my $CustomerUserItemSettings = $ConfigObject->Get('Frontend::CustomerUser::Item');

    {
        my @FileList;

        # get global css
        my $CommonCSSList = $ConfigObject->Get('Loader::Agent::CommonCSS');
        for my $Key ( sort keys %{$CommonCSSList} ) {
            push @FileList, @{ $CommonCSSList->{$Key} };
        }

        # get toolbar module css
        for my $Key ( sort keys %{$ToolbarModuleSettings} ) {
            if ( $ToolbarModuleSettings->{$Key}->{CSS} ) {
                push @FileList, $ToolbarModuleSettings->{$Key}->{CSS};
            }
        }

        # get customer user item css
        for my $Key ( sort keys %{$CustomerUserItemSettings} ) {
            if ( $CustomerUserItemSettings->{$Key}->{CSS} ) {
                push @FileList, $CustomerUserItemSettings->{$Key}->{CSS};
            }
        }

        $Self->_HandleCSSList(
            List      => \@FileList,
            DoMinify  => $DoMinify,
            BlockName => 'CommonCSS',
            SkinHome  => $SkinHome,
            SkinType  => 'Agent',
            Skin      => $SkinSelected,
        );
    }

    # now handle module specific CSS
    my $LoaderAction = $Self->{Action} || 'Login';
    $LoaderAction = 'Login' if ( $LoaderAction eq 'Logout' );

    my $FrontendModuleRegistration = $ConfigObject->Get('Frontend::Module')->{$LoaderAction}
        || {};

    {

        my $AppCSSList = $FrontendModuleRegistration->{Loader}->{CSS} || [];

        my @FileList = @{$AppCSSList};

        $Self->_HandleCSSList(
            List      => \@FileList,
            DoMinify  => $DoMinify,
            BlockName => 'ModuleCSS',
            SkinHome  => $SkinHome,
            SkinType  => 'Agent',
            Skin      => $SkinSelected,
        );
    }

    # handle the responsive CSS
    {
        my @FileList;
        my $ResponsiveCSSList = $ConfigObject->Get('Loader::Agent::ResponsiveCSS');

        for my $Key ( sort keys %{$ResponsiveCSSList} ) {
            push @FileList, @{ $ResponsiveCSSList->{$Key} };
        }

        $Self->_HandleCSSList(
            List      => \@FileList,
            DoMinify  => $DoMinify,
            BlockName => 'ResponsiveCSS',
            SkinHome  => $SkinHome,
            SkinType  => 'Agent',
            Skin      => $SkinSelected,
        );
    }

    #print STDERR "Time: " . Time::HiRes::tv_interval([$t0]);

    return 1;
}

=item LoaderCreateAgentJSCalls()

Generate the minified JS files and the tags referencing them,
taking a list from the Loader::Agent::CommonJS config item.

    $LayoutObject->LoaderCreateAgentJSCalls();

=cut

sub LoaderCreateAgentJSCalls {
    my ( $Self, %Param ) = @_;

    #use Time::HiRes;
    #my $t0 = Time::HiRes::gettimeofday();

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $JSHome   = $ConfigObject->Get('Home') . '/var/httpd/htdocs/js';
    my $DoMinify = $ConfigObject->Get('Loader::Enabled::JS');

    {
        my @FileList;

        # get global js
        my $CommonJSList = $ConfigObject->Get('Loader::Agent::CommonJS');
        for my $Key ( sort keys %{$CommonJSList} ) {
            push @FileList, @{ $CommonJSList->{$Key} };
        }

        # get toolbar module js
        my $ToolbarModuleSettings = $ConfigObject->Get('Frontend::ToolBarModule');
        for my $Key ( sort keys %{$ToolbarModuleSettings} ) {
            if ( $ToolbarModuleSettings->{$Key}->{JavaScript} ) {
                push @FileList, $ToolbarModuleSettings->{$Key}->{JavaScript};
            }
        }

        $Self->_HandleJSList(
            List      => \@FileList,
            DoMinify  => $DoMinify,
            BlockName => 'CommonJS',
            JSHome    => $JSHome,
        );

    }

    # now handle module specific JS
    {
        my $LoaderAction = $Self->{Action} || 'Login';
        $LoaderAction = 'Login' if ( $LoaderAction eq 'Logout' );

        my $AppJSList = $ConfigObject->Get('Frontend::Module')->{$LoaderAction}->{Loader}
            ->{JavaScript} || [];

        my @FileList = @{$AppJSList};

        $Self->_HandleJSList(
            List      => \@FileList,
            DoMinify  => $DoMinify,
            BlockName => 'ModuleJS',
            JSHome    => $JSHome,
        );

    }

    return 1;
}

=item LoaderCreateCustomerCSSCalls()

Generate the minified CSS files and the tags referencing them,
taking a list from the Loader::Customer::CommonCSS config item.

    $LayoutObject->LoaderCreateCustomerCSSCalls();

=cut

sub LoaderCreateCustomerCSSCalls {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $SkinSelected = $ConfigObject->Get('Loader::Customer::SelectedSkin')
        || 'default';

    # force a skin based on host name
    my $DefaultSkinHostBased = $ConfigObject->Get('Loader::Customer::SelectedSkin::HostBased');
    if ( $DefaultSkinHostBased && $ENV{HTTP_HOST} ) {
        REGEXP:
        for my $RegExp ( sort keys %{$DefaultSkinHostBased} ) {

            # do not use empty regexp or skin directories
            next REGEXP if !$RegExp;
            next REGEXP if !$DefaultSkinHostBased->{$RegExp};

            # check if regexp is matching
            if ( $ENV{HTTP_HOST} =~ /$RegExp/i ) {
                $SkinSelected = $DefaultSkinHostBased->{$RegExp};
            }
        }
    }

    my $SkinHome = $ConfigObject->Get('Home') . '/var/httpd/htdocs/skins';
    my $DoMinify = $ConfigObject->Get('Loader::Enabled::CSS');

    {
        my $CommonCSSList = $ConfigObject->Get('Loader::Customer::CommonCSS');

        my @FileList;

        for my $Key ( sort keys %{$CommonCSSList} ) {
            push @FileList, @{ $CommonCSSList->{$Key} };
        }

        $Self->_HandleCSSList(
            List      => \@FileList,
            DoMinify  => $DoMinify,
            BlockName => 'CommonCSS',
            SkinHome  => $SkinHome,
            SkinType  => 'Customer',
            Skin      => $SkinSelected,
        );
    }

    # now handle module specific CSS
    my $LoaderAction = $Self->{Action} || 'Login';
    $LoaderAction = 'Login' if ( $LoaderAction eq 'Logout' );

    my $FrontendModuleRegistration = $ConfigObject->Get('CustomerFrontend::Module')->{$LoaderAction}
        || $ConfigObject->Get('PublicFrontend::Module')->{$LoaderAction}
        || {};

    {
        my $AppCSSList = $FrontendModuleRegistration->{Loader}->{CSS} || [];

        my @FileList = @{$AppCSSList};

        $Self->_HandleCSSList(
            List      => \@FileList,
            DoMinify  => $DoMinify,
            BlockName => 'ModuleCSS',
            SkinHome  => $SkinHome,
            SkinType  => 'Customer',
            Skin      => $SkinSelected,
        );
    }

    # handle the responsive CSS
    {
        my @FileList;
        my $ResponsiveCSSList = $ConfigObject->Get('Loader::Customer::ResponsiveCSS');

        for my $Key ( sort keys %{$ResponsiveCSSList} ) {
            push @FileList, @{ $ResponsiveCSSList->{$Key} };
        }

        $Self->_HandleCSSList(
            List      => \@FileList,
            DoMinify  => $DoMinify,
            BlockName => 'ResponsiveCSS',
            SkinHome  => $SkinHome,
            SkinType  => 'Customer',
            Skin      => $SkinSelected,
        );
    }

    #print STDERR "Time: " . Time::HiRes::tv_interval([$t0]);

    return 1;
}

=item LoaderCreateCustomerJSCalls()

Generate the minified JS files and the tags referencing them,
taking a list from the Loader::Customer::CommonJS config item.

    $LayoutObject->LoaderCreateCustomerJSCalls();

=cut

sub LoaderCreateCustomerJSCalls {
    my ( $Self, %Param ) = @_;

    #use Time::HiRes;
    #my $t0 = Time::HiRes::gettimeofday();

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $JSHome   = $ConfigObject->Get('Home') . '/var/httpd/htdocs/js';
    my $DoMinify = $ConfigObject->Get('Loader::Enabled::JS');

    {
        my $CommonJSList = $ConfigObject->Get('Loader::Customer::CommonJS');

        my @FileList;

        for my $Key ( sort keys %{$CommonJSList} ) {
            push @FileList, @{ $CommonJSList->{$Key} };
        }

        $Self->_HandleJSList(
            List      => \@FileList,
            DoMinify  => $DoMinify,
            BlockName => 'CommonJS',
            JSHome    => $JSHome,
        );

    }

    # now handle module specific JS
    {
        my $LoaderAction = $Self->{Action} || 'CustomerLogin';
        $LoaderAction = 'CustomerLogin' if ( $LoaderAction eq 'Logout' );

        my $AppJSList = $ConfigObject->Get('CustomerFrontend::Module')->{$LoaderAction}->{Loader}
            ->{JavaScript}
            || $ConfigObject->Get('PublicFrontend::Module')->{$LoaderAction}->{Loader}
            ->{JavaScript}
            || [];

        my @FileList = @{$AppJSList};

        $Self->_HandleJSList(
            List      => \@FileList,
            DoMinify  => $DoMinify,
            BlockName => 'ModuleJS',
            JSHome    => $JSHome,
        );

    }

    #print STDERR "Time: " . Time::HiRes::tv_interval([$t0]);
}

sub _HandleCSSList {
    my ( $Self, %Param ) = @_;

    my @Skins = ('default');

    # KIXCore-capeIT
    my %SkinsMap = map { $_ => 1 } @Skins;

    # EO KIXCore-capeIT

    # validating selected custom skin, if any
    # KIXCore-capeIT
    # if ( $Param{Skin} && $Param{Skin} ne 'default' && $Self->SkinValidate(%Param) ) {
    if ( $Param{Skin} && !$SkinsMap{ $Param{Skin} } && $Self->SkinValidate(%Param) ) {

        # EO KIXCore-capeIT
        push @Skins, $Param{Skin};
    }

    # KIXCore-capeIT
    # get paths
    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');
    $Param{SkinHome} =~ m/^$Home(.*)/;
    my $SkinHomeShort = $1;

    # get installed packages
    my @PackagesPaths;
    for my $Package (@INC) {
        next if ( $Package !~ m/^$Home(.*)/ || $Package =~ m/^$Home\/bin/ );
        push @PackagesPaths, $Package;
    }

    # push standard path
    push( @PackagesPaths, $Home );
    my @ReversePaths = reverse @PackagesPaths;

    # get sysconfig option for pre-created loader caches
    my $PreCreatedCaches = $Kernel::OM->Get('Kernel::Config')->Get('Loader::PreCreatedCaches');

    # copy files
    if ( !$PreCreatedCaches ) {
        for my $Skin (@Skins) {
            for my $Path (@ReversePaths) {
                for my $Type (qw(img img/icons css)) {

                    # source directory
                    my $Directory =
                        $Path
                        . $SkinHomeShort . "/"
                        . $Param{SkinType} . "/"
                        . $Skin . "/"
                        . $Type . "/";

                    # target directory
                    my $SkinDirectory =
                        $Param{SkinHome} . "/"
                        . $Param{SkinType} . "/"
                        . $Skin
                        . "/css-cache/"
                        . $Type . "/";

                    # if source directory exists, copy files
                    if ( -e $Directory ) {

                        # get all source files
                        opendir( DIR, $Directory );
                        my @Files = grep { !/^(.|..|icons|thirdparty)$/g } readdir(DIR);
                        closedir(DIR);

                        # check filelist for changes
                        for my $File (@Files) {

                            # check if new directory exists
                            if ( !( -e $SkinDirectory ) ) {
                                if ( !mkpath( $SkinDirectory, 0, 0755 ) ) {
                                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                                        Priority => 'error',
                                        Message  => "Can't create directory '$SkinDirectory': $!",
                                    );
                                    return;
                                }
                            }

                            # check if file does not exist
                            if ( !-e $SkinDirectory . $File ) {
                                copy( $Directory . $File, $SkinDirectory . $File );
                            }

                            # check if file has changed
                            else {
                                my $TargetFileSize = -s $SkinDirectory . $File;
                                my $SourceFileSize = -s $Directory . $File;

                                # copy file if changed
                                if ( $SourceFileSize && $TargetFileSize != $SourceFileSize ) {
                                    my $ok = copy( $Directory . $File, $SkinDirectory . $File );
                                }
                            }
                        }
                    }
                }

                my $DirectoryTP =
                    $Path
                    . $SkinHomeShort . "/"
                    . $Param{SkinType} . "/"
                    . $Skin . "/"
                    . "css/thirdparty/";
                my $SkinDirectoryTP =
                    $Path
                    . $SkinHomeShort . "/"
                    . $Param{SkinType} . "/"
                    . $Skin . "/"
                    . "css-cache/css/thirdparty/";

                if ( -e $DirectoryTP ) {

                    opendir( DIR, $DirectoryTP );
                    my @Files = grep { !/^(.|..)$/g } readdir(DIR);
                    closedir(DIR);

                    $Self->_CopyThirdPartyFiles(
                        FileList   => \@Files,
                        SourcePath => $DirectoryTP,
                        TargetPath => $SkinDirectoryTP
                    );
                }
            }
        }
    }

    # EO KIXCore-capeIT

    # load default css files
    for my $Skin (@Skins) {
        my @FileList;

        CSSFILE:
        for my $CSSFile ( @{ $Param{List} } ) {

            # KIXCore-capeIT
            # my $SkinFile = "$Param{SkinHome}/$Param{SkinType}/$Skin/css/$CSSFile";
            my $SkinFile;
            my $CSSDirectory;

            $SkinFile =
                $Param{SkinHome} . "/"
                . $Param{SkinType} . "/"
                . $Skin . "/"
                . "css-cache/css/"
                . $CSSFile;

            next CSSFILE if !( -e $SkinFile );

            # EO KIXCore-capeIT

            if ( $Param{DoMinify} ) {
                push @FileList, $SkinFile;
            }
            else {
                $Self->Block(
                    Name => $Param{BlockName},
                    Data => {
                        Skin => $Skin,

                        # KIXCore-capeIT
                        # CSSDirectory => 'css',
                        CSSDirectory => "css-cache/css",

                        # EO KIXCore-capeIT
                        Filename => $CSSFile,
                    },
                );
            }
        }

        # KIXCore-capeIT
        if ( $Param{DoMinify} ) {

            # create cache directory for package skins (stored in subdirectory)
            my $KIXCacheDirectory =
                $Param{SkinHome} . "/" . $Param{SkinType} . "/" . $Skin . "/css-cache/css/";
            if ( !-e $KIXCacheDirectory ) {
                if ( !mkpath( $KIXCacheDirectory, 0, 0755 ) ) {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'error',
                        Message  => "Can't create directory '$KIXCacheDirectory': $!",
                    );
                    return;
                }
            }

            if ( ref \@FileList eq 'ARRAY' && scalar @FileList ) {

                # EO KIXCore-capeIT
                my $MinifiedFile = $Kernel::OM->Get('Kernel::System::Loader')->MinifyFiles(
                    List => \@FileList,
                    Type => 'CSS',

                    # KIXCore-capeIT
                    # TargetDirectory      => "$Param{SkinHome}/$Param{SkinType}/$Skin/css-cache/",
                    TargetDirectory => $KIXCacheDirectory,

                    # EO KIXCore-capeIT
                    TargetFilenamePrefix => $Param{BlockName},
                );

                $Self->Block(
                    Name => $Param{BlockName},
                    Data => {
                        Skin => $Skin,

                        # KIXCore-capeIT
                        # CSSDirectory => 'css-cache',
                        CSSDirectory => 'css-cache/css',

                        # EO KIXCore-capeIT
                        Filename => $MinifiedFile,
                    },
                );

                # KIXCore-capeIT
            }

            # EO KIXCore-capeIT
        }
    }

    return 1;
}

# KIXCore-capeIT
sub _CopyThirdPartyFiles {
    my ( $Self, %Param ) = @_;

    my @FileList   = @{ $Param{FileList} };
    my $SourcePath = $Param{SourcePath};
    my $TargetPath = $Param{TargetPath};

    for my $File (@FileList) {
        if ( -d $SourcePath . $File ) {
            my $NewSourcePath = $SourcePath . $File . "/";
            my $NewTargetPath = $TargetPath . $File . "/";

            opendir( DIR, $NewSourcePath );
            my @Files = grep { !/^(.|..)$/g } readdir(DIR);
            closedir(DIR);

            if ( !( -e $NewTargetPath ) ) {

                if ( !mkpath( $NewTargetPath, 0, 0755 ) ) {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'error',
                        Message  => "Can't create directory '$NewTargetPath': $!",
                    );
                    return;
                }
            }

            $Self->_CopyThirdPartyFiles(
                FileList   => \@Files,
                SourcePath => $NewSourcePath,
                TargetPath => $NewTargetPath
            );
        }
        else {

            # check if file does not exist
            if ( !-e $TargetPath . $File ) {
                copy( $SourcePath . $File, $TargetPath . $File );
            }

            # check if file has changed
            else {
                my $TargetFileSize = -s $TargetPath . $File;
                my $SourceFileSize = -s $SourcePath . $File;

                # copy file if changed
                if ( $TargetFileSize != $SourceFileSize ) {
                    my $ok = copy( $SourcePath . $File, $TargetPath . $File );
                }
            }
        }
    }

    return 1;
}

# EO KIXCore-capeIT

sub _HandleJSList {
    my ( $Self, %Param ) = @_;

    my @FileList;

    # KIXCore-capeIT
    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    my @PackagesPaths;
    for my $Package (@INC) {
        next if ( $Package !~ m/^$Home(.*)/ || $Package =~ m/^$Home\/bin/ );
        push @PackagesPaths, $Package;
    }

    my @UsedFiles = ();

    # EO KIXCore-capeIT

    for my $JSFile ( @{ $Param{List} } ) {

        # KIXCore-capeIT
        next if grep { $_ eq $JSFile } @UsedFiles;

        # check packages
        my $JSHome = $Param{JSHome};
        for my $Path (@PackagesPaths) {
            next if ( !-e $Path . '/var/httpd/htdocs/js/' . $JSFile );
            $JSHome = $Path . '/var/httpd/htdocs/js';
            last;
        }
        push @UsedFiles, $JSFile;

        # EO KIXCore-capeIT

        if ( $Param{DoMinify} ) {

            # KIXCore-capeIT
            # push @FileList, "$Param{JSHome}/$JSFile";
            push @FileList, "$JSHome/$JSFile";

            # EO KIXCore-capeIT
        }
        else {
            $Self->Block(
                Name => $Param{BlockName},
                Data => {
                    JSDirectory => '',
                    Filename    => $JSFile,
                },
            );
        }
    }

    if ( $Param{DoMinify} && @FileList ) {
        my $MinifiedFile = $Kernel::OM->Get('Kernel::System::Loader')->MinifyFiles(
            List                 => \@FileList,
            Type                 => 'JavaScript',
            TargetDirectory      => "$Param{JSHome}/js-cache/",
            TargetFilenamePrefix => $Param{BlockName},
        );

        $Self->Block(
            Name => $Param{BlockName},
            Data => {
                JSDirectory => 'js-cache/',
                Filename    => $MinifiedFile,
            },
        );
    }
    return 1;
}

=item SkinValidate()

Returns 1 if skin is available for Agent or Customer frontends and 0 if not.

    my $SkinIsValid = $LayoutObject->SkinValidate(
        UserType => 'Agent'     #  Agent or Customer,
        Skin => 'ExampleSkin',
    );

=cut

sub SkinValidate {
    my ( $Self, %Param ) = @_;

    for my $Needed ( 'SkinType', 'Skin' ) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Message  => "Needed param: $Needed!",
                Priority => 'error',
            );
            return;
        }
    }

    if ( exists $Self->{SkinValidateCache}->{ $Param{SkinType} . '::' . $Param{Skin} } ) {
        return $Self->{SkinValidateCache}->{ $Param{SkinType} . '::' . $Param{Skin} };
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $SkinType      = $Param{SkinType};
    my $PossibleSkins = $ConfigObject->Get("Loader::${SkinType}::Skin") || {};
    my $Home          = $ConfigObject->Get('Home');
    my %ActiveSkins;

    # prepare the list of active skins
    for my $PossibleSkin ( values %{$PossibleSkins} ) {
        if ( $PossibleSkin->{InternalName} eq $Param{Skin} ) {
            my $SkinDir = $Home . "/var/httpd/htdocs/skins/$SkinType/" . $PossibleSkin->{InternalName};
            if ( -d $SkinDir ) {
                $Self->{SkinValidateCache}->{ $Param{SkinType} . '::' . $Param{Skin} } = 1;
                return 1;
            }
        }
    }

    $Self->{SkinValidateCache}->{ $Param{SkinType} . '::' . $Param{Skin} } = undef;
    return;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
