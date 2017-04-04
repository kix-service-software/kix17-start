# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

%Config = (
   Search => {

       # tickets created in the last 120 minutes
       TicketID => 1,
   },

# Declaration of thresholds
# min_warn_treshold > Number of tickets -> WARNING
# max_warn_treshold < Number of tickets -> WARNING
# min_crit_treshold > Number of tickets -> ALARM
# max_warn_treshold < Number of tickets -> ALARM

   min_warn_treshold => 0,
   max_warn_treshold => 10,
   min_crit_treshold => 0,
   max_crit_treshold => 20,

# Information used by Nagios
# Name of check shown in Nagios Status Information
   checkname => 'OTRS Checker',

# Text shown in Status Information if everything is OK
   OK_TXT    => 'enjoy   tickets:',

# Text shown in Status Information if warning threshold reached
   WARN_TXT  => 'number of tickets:',

# Text shown in Status Information if critical threshold reached
   CRIT_TXT  => 'critical number of tickets:',

);




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
