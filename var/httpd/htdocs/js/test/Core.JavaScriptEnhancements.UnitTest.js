// --
// Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
// based on the original work of:
// Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};

Core.JavaScriptEnhancements = {};
Core.JavaScriptEnhancements.RunUnitTests = function(){

    module('Core.JavaScriptEnhancements');

    test('isJQueryObject()', function(){
        expect(6);

        equal(isJQueryObject($([])), true, 'empty jQuery object');
        equal(isJQueryObject($('body')), true, 'simple jQuery object');
        equal(isJQueryObject({}), false, 'plain object');
        equal(isJQueryObject(undefined), false, 'undefined');
        equal(isJQueryObject($([]), $([])), true, 'multiple');
        equal(isJQueryObject($([]), $([]), {}), false, 'multiple, one plain object');
    });
};
