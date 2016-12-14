// --
// Core.KIX4OTRS.Agent.TicketMergeLink.js - provides the special module functions to create clickable link for merged tickets
// Copyright (C) 2006-2015 c.a.p.e. IT GmbH, http://www.cape-it.de
//
// written/edited by:
//   Frank(dot)Oberender(at)cape(dash)it(dot)de
//   Martin(dot)Balzarek(at)cape(dash)it(dot)de
//
// --
// $Id$
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.KIX4OTRS = Core.KIX4OTRS || {};
Core.KIX4OTRS.Agent = Core.KIX4OTRS.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIX4OTRS.Agent.TicketMergeLink
 * @description This namespace contains the special module functions to create
 *              clickable link for merged tickets.
 */
Core.KIX4OTRS.Agent.TicketMergeLink = (function(TargetNS) {
    if (!$('iframe').length)
        return TargetNS;

    $('iframe').bind('load', function() {
        var $body = $(this.contentDocument).find('body'), content = $body.html();

        if (content.search(/<!-- KIX4OTRS MergeTargetLinkEnd -->/) != -1) {
            content = content.replace(/<!--\sKIX4OTRS\sMergeTargetLinkStart\s::(.*)::\s-->/g, '<a  href="index.pl?Action=AgentTicketZoom;TicketID=$1" target="new">');
            content = content.replace(/<!-- KIX4OTRS MergeTargetLinkEnd -->/g, "</a>");
            $body.html(content);
        }
    });

    return TargetNS;
}(Core.KIX4OTRS.Agent.TicketMergeLink || {}));
