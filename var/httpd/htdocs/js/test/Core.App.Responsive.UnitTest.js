// --
// Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
// based on the original work of:
// Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.App = Core.App || {};

Core.App.Responsive = (function (Namespace) {
    Namespace.RunUnitTests = function(){

        module('Core.App.Responsive');

        test('IsSmallerOrEqual', function(){
            expect(4);

            ok(Core.App.Responsive.IsSmallerOrEqual('ScreenL', 'ScreenXL'));
            ok(Core.App.Responsive.IsSmallerOrEqual('ScreenXS', 'ScreenL'));
            ok(Core.App.Responsive.IsSmallerOrEqual('ScreenM', 'ScreenM'));
            ok(!Core.App.Responsive.IsSmallerOrEqual('ScreenL', 'ScreenM'));
        });
    };

    return Namespace;
}(Core.App.Responsive || {}));
