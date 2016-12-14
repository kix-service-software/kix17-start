# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# Provides methods required for registration of KIX-modules and other usefull
# methods which are hard to assign to some specific object.
#
# written/edited by:
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Frank(dot)Oberender(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# * Anna(dot)Litvinova(at)cape(dash)it(dot)de
#
# --
# $Id$
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::KIXUtils;

use strict;
use warnings;

use File::Copy;

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Time',
);

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $PackageObject = $Kernel::OM->Get('Kernel::System::Package');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{MainObject}   = $Kernel::OM->Get('Kernel::System::Main');
    $Self->{TimeObject}   = $Kernel::OM->Get('Kernel::System::Time');

    $Self->{KIXFRAMEWORKSTRING_START} = '#----------- KIX tsunami framework -----------';
    $Self->{KIXFRAMEWORKSTRING_END}   = '#----------- EO KIX tsunami framework -----------';

    $Self->{KIXFRAMEWORKSTRING} = "\n"
        . $Self->{KIXFRAMEWORKSTRING_START}
        . "\n"
        . '# CustomPackageLibs ~#'
        . "\n"
        . '# EO CustomPackageLibs ~#'
        . "\n"
        . $Self->{KIXFRAMEWORKSTRING_END}
        . "\n";

    $Self->{KIXFRAMEWORKSTRING_MODPERL} = "\n"
        . $Self->{KIXFRAMEWORKSTRING_START}
        . "\n"
        . '# CustomPackageLibs ~#'
        . "\n"
        . '# EO CustomPackageLibs ~#'
        . "\n"
        . $Self->{KIXFRAMEWORKSTRING_END}
        . "\n";

    return $Self;
}

=item RegisterCustomPackage()

    my $Var = $KIXUtilsObject->RegisterCustomPackage(
        PackageName => "KIX_ITSM",
        Priority    => "1234",
    );

=cut

sub RegisterCustomPackage {
    my ( $Self, %Param ) = @_;

    # check mandatory parameters
    for (qw(PackageName Priority)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $CustomPackages = $Self->GetRegisteredCustomPackages();

    #delete current configuration for this package...
    if ( $CustomPackages && ref($CustomPackages) ne 'HASH' ) {
        for my $CurrPrio ( keys( %{$CustomPackages} ) ) {
            if (
                $CustomPackages->{$CurrPrio}
                && ( $CustomPackages->{$CurrPrio} eq $Param{PackageName} )
                )
            {
                delete( $CustomPackages->{$CurrPrio} );
            }
        }
    }

    # set (new) priority for this package...
    $CustomPackages->{ $Param{Priority}.'::'.$Param{PackageName} } = $Param{PackageName};

    $Self->SetRegisteredCustomPackages( CustomPackages => $CustomPackages, );

    return 1;
}

=item UnRegisterCustomPackage()

   Removes a tsunami-extension from the KIX_Packages file.

   my $Var = $KIXUtilsObject->UnRegisterCustomPackage( "KIX_ITSM" );

=cut

sub UnRegisterCustomPackage {
    my ( $Self, %Param ) = @_;

    # check mandatory parameters
    for (qw(PackageName)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $CustomPackages = $Self->GetRegisteredCustomPackages();

    return if ( !$CustomPackages || ref($CustomPackages) ne 'HASH' );

    for my $CurrPrio ( keys( %{$CustomPackages} ) ) {
        if (
            $CustomPackages->{$CurrPrio}
            && ( $CustomPackages->{$CurrPrio} eq $Param{PackageName} )
            )
        {
            delete( $CustomPackages->{$CurrPrio} );
        }
    }

    $Self->SetRegisteredCustomPackages( CustomPackages => $CustomPackages, );

    return 1;
}

=item GetRegisteredCustomPackages()

   Returns a hash ref containing all registered custom packages. Key denotes the priority of the package (value) order.

   my %CustomPackageList = $KIXUtilsObject->GetRegisteredCustomPackages(
       Result => 'ARRAY', #optional - returns sorted list of custom packages instead of hash ref
   );

=cut

sub GetRegisteredCustomPackages {
    my ( $Self, %Param ) = @_;
    my %RetVal = ();

    my $Home = $Self->{ConfigObject}->Get('Home');
    if ( $Home !~ m{^.*\/$}x ) {
        $Home .= '/';
    }
    my $KIXPackageFile = $Home . 'KIXCore/CustomPackages.cfg';

    if ( open( my $FH, '<', $KIXPackageFile ) ) {
        while (<$FH>) {
            my $Line = $_;
            chomp($Line);
            next if ( $Line !~ /(.+)::(.+)/ );
            $RetVal{$Line} = $2;
        }
        close($FH);
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "KIX-Install: could not read <$KIXPackageFile> - using empty hash.",
        );
    }

    if ( $Param{Result} && $Param{Result} eq 'ARRAY' ) {
        my @Result = qw{};
        for my $CurrKey ( sort( keys(%RetVal) ) ) {
            push( @Result, $RetVal{$CurrKey} );
        }
        return @Result;
    }

    return \%RetVal;
}

=item SetRegisteredCustomPackages()

   Writes the CustomPackage configuration to file - automatically adds custom package "KIXCore" at priority "0000".

   my $Result = $KIXUtilsObject->SetRegisteredCustomPackages(
       CustomPackages => $HashRef,
   );

=cut

sub SetRegisteredCustomPackages {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    # check mandatory parameters
    for (qw(CustomPackages)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $Home = $Self->{ConfigObject}->Get('Home');
    if ( $Home !~ m{^.*\/$}x ) {
        $Home .= '/';
    }
    my $KIXPackageFile = $Home . 'KIXCore/CustomPackages.cfg';

    # backup old config
    if ( !$Param{Rebuild} ) {
        my ( $s, $m, $h, $D, $M, $Y ) = $Self->{TimeObject}->SystemTime2Date(
            SystemTime => $Self->{TimeObject}->SystemTime(),
        );
        $M = sprintf '%02d', $M;
        $D = sprintf '%02d', $D;
        $h = sprintf '%02d', $h;
        $m = sprintf '%02d', $m;
        my $TimestampSuffix = "$Y-$M-$D" . "_$h-$m";
        copy( $KIXPackageFile, "$KIXPackageFile.PreCustomPackageRegistration.$TimestampSuffix" );
    }

    #---------------------------------------------------------------------------
    # update storage for custom packages in <OTRS_HOME>/KIXCore/CustomPackages...

    # enforce "KIXCore" custom package...
    $Param{CustomPackages}->{'0000::KIXCore'} = 'KIXCore';

    if ( open( my $FH, '>', $KIXPackageFile ) ) {
        my $FileContent = '';
        for my $CurrPrioKey ( sort keys %{ $Param{CustomPackages} } ) {
            $FileContent .= $CurrPrioKey . "\n";
        }
        print $FH $FileContent;
        close($FH);
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "KIX-Install: could not write <$KIXPackageFile> !",
        );
    }

    # update our Config.pm
    $Self->_UpdateConfigPm(
        %Param,
        Home => $Home,
    );

    # update our apache perl startup script
    $Self->_UpdateApachePerlStartup(
        %Param,
        Home => $Home,
    );

    # update our cgi-bin scripts
    $Self->_UpdateCGIScripts(
        %Param,
        Home => $Home,
    );

    #---------------------------------------------------------------------------
    # change @INC to allow usage of custom modules in CodeInstall...
    # !!! This does not work with mod_perl) !!!
    for my $CurrPrioKey ( sort keys %{ $Param{CustomPackages} } ) {
        unshift( @INC, $Home . $Param{CustomPackages}->{$CurrPrioKey} );
    }

    return $Result;
}

=item CleanUpConfigPm()

   Removes file created by KIXCore re-/installation and all related lines from Kernel/Config.pm and scripts/apache2-perl-startup.pl.

   my $Result = $KIXUtilsObject->CleanUpConfigPm();

=cut

sub CleanUpConfigPm {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    my $Home = $Self->{ConfigObject}->Get('Home');
    if ( $Home !~ m{^.*\/$}x ) {
        $Home .= '/';
    }
    my $KIXPackageFile = $Home . 'KIXCore/CustomPackages.cfg';

    #---------------------------------------------------------------------------
    # delete storage for custom packages in <OTRS_HOME>/KIXCore/CustomPackages...
    if ( unlink($KIXPackageFile) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "KIX-Install: deleted <$KIXPackageFile> !",
        );
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "KIX-Install: could not delete <$KIXPackageFile> !",
        );
    }

    #---------------------------------------------------------------------------
    # update use lib configuration for custom packages Config.pm...
    my $ConfigFile = $Home . 'Kernel/Config.pm';

    # get current Config.pm content
    my $ConfigFileContentOrig = '';
    my $ConfigFileContentNew  = '';

    if ( open( my $IN, '<', $ConfigFile ) ) {
        while ( my $Line = <$IN> ) {
            $ConfigFileContentOrig .= $Line;
        }
        close($IN);
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not open file $ConfigFile!",
        );
        return;
    }

    $ConfigFileContentNew = $ConfigFileContentOrig;
    $ConfigFileContentNew =~
        s{$Self->{KIXFRAMEWORKSTRING_START}(.+)$Self->{KIXFRAMEWORKSTRING_END}}{}msg;

    #---------------------------------------------------------------------------
    # add new content to Config.pm
    if ( length($ConfigFileContentNew) ) {

        if ( open( my $OUT, '>', $ConfigFile ) ) {

            binmode($OUT);
            print $OUT $ConfigFileContentNew;
            close($OUT);

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Updated $ConfigFile.",
            );

            $Result = 1;

        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Could not open or edit file $ConfigFile!",
            );
        }
    }

    #---------------------------------------------------------------------------
    # update use lib configuration for custom packages apache2-perl-startup.pl
    my $Apache2PerlStartUpFile = $Home . 'scripts/apache2-perl-startup.pl';

    # get current Config.pm content
    my $Apache2PerlStartUpFileContentOrig = '';
    my $Apache2PerlStartUpFileContentNew  = '';

    if ( open( my $IN, '<', $Apache2PerlStartUpFile ) ) {
        while ( my $Line = <$IN> ) {
            $Apache2PerlStartUpFileContentOrig .= $Line;
        }
        close($IN);
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not open file $Apache2PerlStartUpFile!",
        );
        return;
    }

    $Apache2PerlStartUpFileContentNew = $Apache2PerlStartUpFileContentOrig;
    $Apache2PerlStartUpFileContentNew =~
        s{$Self->{KIXFRAMEWORKSTRING_START}(.+)$Self->{KIXFRAMEWORKSTRING_END}}{}msg;

    #---------------------------------------------------------------------------
    # add new content to apache2-perl-startup.pl
    if ( length($Apache2PerlStartUpFileContentNew) ) {

        if ( open( my $OUT, '>', $Apache2PerlStartUpFile ) ) {

            binmode($OUT);
            print $OUT $Apache2PerlStartUpFileContentNew;
            close($OUT);

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Updated $Apache2PerlStartUpFile.",
            );

            $Result = 1;

        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Could not open or edit file $Apache2PerlStartUpFile!",
            );
        }
    }

    return $Result;
}

=item RebuildConfig()

    my $Var = $KIXUtilsObject->RebuildConfig();

=cut

sub RebuildConfig {
    my ( $Self, %Param ) = @_;

    my $CustomPackages = $Self->GetRegisteredCustomPackages();
    $Self->SetRegisteredCustomPackages( CustomPackages => $CustomPackages, Rebuild => 1 );

    return 1;
}

=item _UpdateConfigPm()

    my $Var = $KIXUtilsObject->_UpdateConfigPm(
        Home => '...'
    );

=cut

sub _UpdateConfigPm {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    # check mandatory parameters
    for (qw(Home)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $Home = $Param{Home};

    #---------------------------------------------------------------------------
    # update use lib configuration for custom packages Config.pm...
    my $ConfigFile = $Home . 'Kernel/Config.pm';

    # get current Config.pm content
    my $ConfigFileContentOrig   = '';
    my $ConfigFileContentNew    = '';
    my $PackageConfigLine       = 0;
    my $PackageConfigLinesFound = 0;

    if ( open( my $IN, '<', $ConfigFile ) ) {
        while ( my $Line = <$IN> ) {
            if ( $Line =~ /\s*# CustomPackageLibs ~#\s$";/ ) {
                $PackageConfigLinesFound = 1;
            }
            $ConfigFileContentOrig .= $Line;

        }
        close($IN);
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not open file $ConfigFile!",
        );
        return;
    }

    # if no lines like "# CustomPackageLibs ~#" found, add complete KIXFRAMEWORKSTRING string...
    if ( !$PackageConfigLinesFound ) {
        $ConfigFileContentOrig =~ s/1;\s*$//gx;
        $ConfigFileContentNew = $ConfigFileContentOrig . $Self->{KIXFRAMEWORKSTRING} . "\n1;";
    }

    #---------------------------------------------------------------------------
    # get new additional Config.pm content
    my $CustomPackageLibSample             = 'use lib "' . $Home . '<PACKAGENAME>";' . "\n";
    my $ConfigFileContentCustomPackageLibs = '# CustomPackageLibs ~#' . "\n";

    for my $CurrPrioKey ( sort keys %{ $Param{CustomPackages} } ) {
        $ConfigFileContentCustomPackageLibs .= $CustomPackageLibSample;
        $ConfigFileContentCustomPackageLibs =~
            s/<PACKAGENAME>/$Param{CustomPackages}->{$CurrPrioKey}/g;
    }

    $ConfigFileContentCustomPackageLibs .= "# EO CustomPackageLibs ~#";

    $ConfigFileContentNew =~
        s{# CustomPackageLibs ~#(.+)# EO CustomPackageLibs ~#}{$ConfigFileContentCustomPackageLibs}msg;

    #---------------------------------------------------------------------------
    # add new content to Config.pm
    if ( length($ConfigFileContentNew) ) {

        if ( open( my $OUT, '>', $ConfigFile ) ) {

            binmode($OUT);
            print $OUT $ConfigFileContentNew;
            close($OUT);

            my ( $s, $m, $h, $D, $M, $Y ) = $Self->{TimeObject}->SystemTime2Date(
                SystemTime => $Self->{TimeObject}->SystemTime(),
            );
            $M = sprintf '%02d', $M;
            $D = sprintf '%02d', $D;
            $h = sprintf '%02d', $h;
            $m = sprintf '%02d', $m;
            my $TimestampSuffix = "$Y-$M-$D" . "_$h-$m";
            if ( open( $OUT, '>', "$ConfigFile.PreCustomPackageRegistration.$TimestampSuffix" ) ) {
                binmode($OUT);
                print $OUT $ConfigFileContentOrig;
                close($OUT);
            }

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Updated $ConfigFile.",
            );

            $Result = 1;

        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Could not open or edit file $ConfigFile!",
            );
        }
    }

    return $Result;
}

=item _UpdateApachePerlStartup()

    my $Var = $KIXUtilsObject->_UpdateApachePerlStartup(
        Home => '...'
    );

=cut

sub _UpdateApachePerlStartup {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    # check mandatory parameters
    for (qw(Home)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $Home = $Param{Home};

    #---------------------------------------------------------------------------
    # update use lib configuration for custom packages apache2-perl-startup.pl...
    my $Apache2PerlStartUp = $Home . 'scripts/apache2-perl-startup.pl';

    # get current apache2-perl-startup.pl content
    my $Apache2PerlStartUpContentOrig = '';
    my $Apache2PerlStartUpContentNew  = '';
    my $PathPrefix                    = $Home;
    $PathPrefix =~ s/\/$//;    # needed for regex
    my $PackageConfigLine       = 0;
    my $PackageConfigLinesFound = 0;

    if ( open( my $IN, '<', $Apache2PerlStartUp ) ) {
        while ( my $Line = <$IN> ) {
            if ( $Line =~ /\s*# CustomPackageLibs ~#\s$";/ ) {
                $PackageConfigLinesFound = 1;
            }
            $Apache2PerlStartUpContentOrig .= $Line;

        }
        close($IN);
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not open file $Apache2PerlStartUp!",
        );
        return;
    }

    # if no lines like "# CustomPackageLibs ~#" found, add complete KIXFRAMEWORKSTRING string...
    if ( !$PackageConfigLinesFound ) {
        $Apache2PerlStartUpContentNew = $Apache2PerlStartUpContentOrig;
        $Self->{KIXFRAMEWORKSTRING_MODPERL}
            = 'use lib "' . $PathPrefix . '/Custom";' . "\n" . $Self->{KIXFRAMEWORKSTRING_MODPERL};
        $Apache2PerlStartUpContentNew
            =~ s{use lib "$PathPrefix/Custom";}{$Self->{KIXFRAMEWORKSTRING_MODPERL}}msg;
    }

    #---------------------------------------------------------------------------
    # get new additional apache2-perl-startup.pl content
    my $CustomPackageLibSample = "\n"
        . 'use lib "' . $PathPrefix . '/<PACKAGENAME>";';
    my $Apache2PerlStartUpContentCustomPackageLibs = "# CustomPackageLibs ~#";

    for my $CurrPrioKey ( sort keys %{ $Param{CustomPackages} } ) {
        $Apache2PerlStartUpContentCustomPackageLibs .= $CustomPackageLibSample;
        $Apache2PerlStartUpContentCustomPackageLibs =~
            s/<PACKAGENAME>/$Param{CustomPackages}->{$CurrPrioKey}/g;
    }

    $Apache2PerlStartUpContentCustomPackageLibs .= "# EO CustomPackageLibs ~#";

    $Apache2PerlStartUpContentNew =~
        s{# CustomPackageLibs ~#(.+)# EO CustomPackageLibs ~#}{$Apache2PerlStartUpContentCustomPackageLibs}msg;

    #---------------------------------------------------------------------------
    # add new content to apache2-perl-startup.pl
    if ( length($Apache2PerlStartUpContentNew) ) {

        if ( open( my $OUT, '>', $Apache2PerlStartUp ) ) {

            binmode($OUT);
            print $OUT $Apache2PerlStartUpContentNew;
            close($OUT);

            my ( $s, $m, $h, $D, $M, $Y ) = $Self->{TimeObject}->SystemTime2Date(
                SystemTime => $Self->{TimeObject}->SystemTime(),
            );
            $M = sprintf '%02d', $M;
            $D = sprintf '%02d', $D;
            $h = sprintf '%02d', $h;
            $m = sprintf '%02d', $m;
            my $TimestampSuffix = "$Y-$M-$D" . "_$h-$m";
            if (
                open(
                    $OUT, '>', "$Apache2PerlStartUp.PreCustomPackageRegistration.$TimestampSuffix"
                )
                )
            {
                binmode($OUT);
                print $OUT $Apache2PerlStartUpContentOrig;
                close($OUT);
            }

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Updated $Apache2PerlStartUp.",
            );

            $Result = 1;

        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Could not open or edit file $Apache2PerlStartUp!",
            );
        }
    }

    return $Result;
}

=item _UpdateCGIScripts()

    my $Var = $KIXUtilsObject->_UpdateCGIScripts(
        Home => '...'
    );

=cut

sub _UpdateCGIScripts {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    # check mandatory parameters
    for (qw(Home)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $Home = $Param{Home};

    #---------------------------------------------------------------------------
    # update use lib configuration for all CGI pl scripts...
    opendir( DIR, "$Home/bin/cgi-bin" );
    my @ScriptFiles = grep {/^.*\.pl$/g} readdir(DIR);
    closedir(DIR);

    foreach my $ScriptFile (@ScriptFiles) {
        # ignore faq.pl
        next if $ScriptFile eq 'faq.pl';

        my $ScriptFile = "$Home/bin/cgi-bin/$ScriptFile";

        # get current file content
        my $ScriptFileContentOrig = '';
        my $ScriptFileContentNew  = '';
        my $PathPrefix            = $Home;
        $PathPrefix =~ s/\/$//;    # needed for regex
        my $PackageConfigLine       = 0;
        my $PackageConfigLinesFound = 0;

        if ( open( my $IN, '<', $ScriptFile ) ) {
            while ( my $Line = <$IN> ) {
                if ( $Line =~ /\s*# CustomPackageLibs ~#\s$";/ ) {
                    $PackageConfigLinesFound = 1;
                }
                $ScriptFileContentOrig .= $Line;

            }
            close($IN);
        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Could not open file $ScriptFile!",
            );
            next;
        }

        # if no lines like "# CustomPackageLibs ~#" found, add complete KIXFRAMEWORKSTRING string...
        if ( !$PackageConfigLinesFound ) {
            $ScriptFileContentNew = $ScriptFileContentOrig;
            $ScriptFileContentNew =~
                s{use lib "\$Bin/../../Custom";}{use lib "\$Bin/../../Custom";\n$Self->{KIXFRAMEWORKSTRING}}msg;
        }

        #---------------------------------------------------------------------------
        # get new additional file content
        my $CustomPackageLibSample             = 'use lib "' . $Home . '<PACKAGENAME>";' . "\n";
        my $ScriptFileContentCustomPackageLibs = '# CustomPackageLibs ~#' . "\n";

        for my $CurrPrioKey ( sort keys %{ $Param{CustomPackages} } ) {
            $ScriptFileContentCustomPackageLibs .= $CustomPackageLibSample;
            $ScriptFileContentCustomPackageLibs =~
                s/<PACKAGENAME>/$Param{CustomPackages}->{$CurrPrioKey}/g;
        }

        $ScriptFileContentCustomPackageLibs .= "# EO CustomPackageLibs ~#";

        $ScriptFileContentNew =~
            s{# CustomPackageLibs ~#(.+)# EO CustomPackageLibs ~#}{$ScriptFileContentCustomPackageLibs}msg;

        #---------------------------------------------------------------------------
        # add new content to file
        if ( length($ScriptFileContentNew) ) {

            if ( open( my $OUT, '>', $ScriptFile ) ) {

                binmode($OUT);
                print $OUT $ScriptFileContentNew;
                close($OUT);

                my ( $s, $m, $h, $D, $M, $Y ) = $Self->{TimeObject}->SystemTime2Date(
                    SystemTime => $Self->{TimeObject}->SystemTime(),
                );
                $M = sprintf '%02d', $M;
                $D = sprintf '%02d', $D;
                $h = sprintf '%02d', $h;
                $m = sprintf '%02d', $m;
                my $TimestampSuffix = "$Y-$M-$D" . "_$h-$m";
                if (
                    open( $OUT, '>', "$ScriptFile.PreCustomPackageRegistration.$TimestampSuffix" )
                    )
                {
                    binmode($OUT);
                    print $OUT $ScriptFileContentOrig;
                    close($OUT);
                }

                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'notice',
                    Message  => "Updated $ScriptFile.",
                );

                $Result = 1;

            }
            else {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Could not open or edit file $ScriptFile!",
                );
            }
        }
    }

    return $Result;
}

1;
