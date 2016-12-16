-- ----------------------------------------------------------
--  driver: postgresql
-- ----------------------------------------------------------
SET standard_conforming_strings TO ON;
-- ----------------------------------------------------------
--  insert into table valid
-- ----------------------------------------------------------
INSERT INTO valid (name, create_by, create_time, change_by, change_time)
    VALUES
    ('valid', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table valid
-- ----------------------------------------------------------
INSERT INTO valid (name, create_by, create_time, change_by, change_time)
    VALUES
    ('invalid', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table valid
-- ----------------------------------------------------------
INSERT INTO valid (name, create_by, create_time, change_by, change_time)
    VALUES
    ('invalid-temporarily', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table users
-- ----------------------------------------------------------
INSERT INTO users (first_name, last_name, login, pw, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Admin', 'KIX', 'root@localhost', 'roK20XGbWEsSM', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table groups
-- ----------------------------------------------------------
INSERT INTO groups (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('users', 'Group for default access.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table groups
-- ----------------------------------------------------------
INSERT INTO groups (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('admin', 'Group of all administrators.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table groups
-- ----------------------------------------------------------
INSERT INTO groups (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('stats', 'Group for statistics access.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table groups
-- ----------------------------------------------------------
INSERT INTO groups (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('faq', 'faq database users', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table groups
-- ----------------------------------------------------------
INSERT INTO groups (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('faq_admin', 'faq admin users', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table groups
-- ----------------------------------------------------------
INSERT INTO groups (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('faq_approval', 'faq approval users', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table groups
-- ----------------------------------------------------------
INSERT INTO groups (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('itsm-configitem', 'Group for ITSM ConfigItem mask access in the agent interface.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table groups
-- ----------------------------------------------------------
INSERT INTO groups (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('itsm-service', 'Group for ITSM Service mask access in the agent interface.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table groups
-- ----------------------------------------------------------
INSERT INTO groups (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('SwitchButton', 'created by SwitchButton installer', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table group_user
-- ----------------------------------------------------------
INSERT INTO group_user (user_id, group_id, permission_key, permission_value, create_by, create_time, change_by, change_time)
    VALUES
    (1, 1, 'rw', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table group_user
-- ----------------------------------------------------------
INSERT INTO group_user (user_id, group_id, permission_key, permission_value, create_by, create_time, change_by, change_time)
    VALUES
    (1, 2, 'rw', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table group_user
-- ----------------------------------------------------------
INSERT INTO group_user (user_id, group_id, permission_key, permission_value, create_by, create_time, change_by, change_time)
    VALUES
    (1, 3, 'rw', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table link_type
-- ----------------------------------------------------------
INSERT INTO link_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Normal', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table link_type
-- ----------------------------------------------------------
INSERT INTO link_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('ParentChild', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table link_type
-- ----------------------------------------------------------
INSERT INTO link_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('Agent', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table link_type
-- ----------------------------------------------------------
INSERT INTO link_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('Customer', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table link_type
-- ----------------------------------------------------------
INSERT INTO link_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('3rdParty', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table link_state
-- ----------------------------------------------------------
INSERT INTO link_state (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Valid', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table link_state
-- ----------------------------------------------------------
INSERT INTO link_state (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Temporary', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table link_object
-- ----------------------------------------------------------
INSERT INTO link_object (name)
    VALUES
    ('Person');
-- ----------------------------------------------------------
--  insert into table ticket_state_type
-- ----------------------------------------------------------
INSERT INTO ticket_state_type (name, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('new', 'All new state types (default: viewable).', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state_type
-- ----------------------------------------------------------
INSERT INTO ticket_state_type (name, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('open', 'All open state types (default: viewable).', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state_type
-- ----------------------------------------------------------
INSERT INTO ticket_state_type (name, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('closed', 'All closed state types (default: not viewable).', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state_type
-- ----------------------------------------------------------
INSERT INTO ticket_state_type (name, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('pending reminder', 'All ''pending reminder'' state types (default: viewable).', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state_type
-- ----------------------------------------------------------
INSERT INTO ticket_state_type (name, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('pending auto', 'All ''pending auto *'' state types (default: viewable).', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state_type
-- ----------------------------------------------------------
INSERT INTO ticket_state_type (name, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('removed', 'All ''removed'' state types (default: not viewable).', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state_type
-- ----------------------------------------------------------
INSERT INTO ticket_state_type (name, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('merged', 'State type for merged tickets (default: not viewable).', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state
-- ----------------------------------------------------------
INSERT INTO ticket_state (name, comments, type_id, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('new', 'New ticket created by customer.', 1, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state
-- ----------------------------------------------------------
INSERT INTO ticket_state (name, comments, type_id, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('closed successful', 'Ticket is closed successful.', 3, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state
-- ----------------------------------------------------------
INSERT INTO ticket_state (name, comments, type_id, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('closed unsuccessful', 'Ticket is closed unsuccessful.', 3, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state
-- ----------------------------------------------------------
INSERT INTO ticket_state (name, comments, type_id, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('open', 'Open tickets.', 2, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state
-- ----------------------------------------------------------
INSERT INTO ticket_state (name, comments, type_id, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('removed', 'Customer removed ticket.', 6, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state
-- ----------------------------------------------------------
INSERT INTO ticket_state (name, comments, type_id, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('pending reminder', 'Ticket is pending for agent reminder.', 4, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state
-- ----------------------------------------------------------
INSERT INTO ticket_state (name, comments, type_id, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('pending auto close+', 'Ticket is pending for automatic close.', 5, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state
-- ----------------------------------------------------------
INSERT INTO ticket_state (name, comments, type_id, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('pending auto close-', 'Ticket is pending for automatic close.', 5, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state
-- ----------------------------------------------------------
INSERT INTO ticket_state (name, comments, type_id, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('merged', 'State for merged tickets.', 7, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_state
-- ----------------------------------------------------------
INSERT INTO ticket_state (name, comments, type_id, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('closed with workaround', 'ticket is closed with workaround', 3, 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table ticket_state
-- ----------------------------------------------------------
INSERT INTO ticket_state (name, comments, type_id, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('pending auto reopen', 'Ticket is pending for automatic reopen', 5, 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table salutation
-- ----------------------------------------------------------
INSERT INTO salutation (name, text, content_type, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('system standard salutation (en)', 'Dear <OTRS_CUSTOMER_REALNAME>,

Thank you for your request.

', 'text/plain; charset=utf-8', 'Standard Salutation.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table signature
-- ----------------------------------------------------------
INSERT INTO signature (name, text, content_type, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('system standard signature (en)', '
Your Ticket-Team

 <OTRS_Agent_UserFirstname> <OTRS_Agent_UserLastname>

--
 Super Support - Waterford Business Park
 5201 Blue Lagoon Drive - 8th Floor & 9th Floor - Miami, 33126 USA
 Email: hot@example.com - Web: http://www.example.com/
--', 'text/plain; charset=utf-8', 'Standard Signature.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table system_address
-- ----------------------------------------------------------
INSERT INTO system_address (value0, value1, comments, valid_id, queue_id, create_by, create_time, change_by, change_time)
    VALUES
    ('otrs@localhost', 'OTRS System', 'Standard Address.', 1, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table follow_up_possible
-- ----------------------------------------------------------
INSERT INTO follow_up_possible (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('possible', 'Follow-ups for closed tickets are possible. Ticket will be reopened.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table follow_up_possible
-- ----------------------------------------------------------
INSERT INTO follow_up_possible (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('reject', 'Follow-ups for closed tickets are not possible. No new ticket will be created.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table follow_up_possible
-- ----------------------------------------------------------
INSERT INTO follow_up_possible (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('new ticket', 'Follow-ups for closed tickets are not possible. A new ticket will be created..', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table queue
-- ----------------------------------------------------------
INSERT INTO queue (name, group_id, system_address_id, salutation_id, signature_id, follow_up_id, follow_up_lock, unlock_timeout, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Postmaster', 1, 1, 1, 1, 1, 0, 0, 'Postmaster queue.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table queue
-- ----------------------------------------------------------
INSERT INTO queue (name, group_id, system_address_id, salutation_id, signature_id, follow_up_id, follow_up_lock, unlock_timeout, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Raw', 1, 1, 1, 1, 1, 0, 0, 'All default incoming tickets.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table queue
-- ----------------------------------------------------------
INSERT INTO queue (name, group_id, system_address_id, salutation_id, signature_id, follow_up_id, follow_up_lock, unlock_timeout, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Junk', 1, 1, 1, 1, 1, 0, 0, 'All junk tickets.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table queue
-- ----------------------------------------------------------
INSERT INTO queue (name, group_id, system_address_id, salutation_id, signature_id, follow_up_id, follow_up_lock, unlock_timeout, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Misc', 1, 1, 1, 1, 1, 0, 0, 'All misc tickets.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table standard_template
-- ----------------------------------------------------------
INSERT INTO standard_template (name, text, content_type, template_type, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('empty answer', '', 'text/plain; charset=utf-8', 'Answer', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table standard_template
-- ----------------------------------------------------------
INSERT INTO standard_template (name, text, content_type, template_type, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('test answer', 'Some test answer to show how a standard template can be used.', 'text/plain; charset=utf-8', 'Answer', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table queue_standard_template
-- ----------------------------------------------------------
INSERT INTO queue_standard_template (queue_id, standard_template_id, create_by, create_time, change_by, change_time)
    VALUES
    (1, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table queue_standard_template
-- ----------------------------------------------------------
INSERT INTO queue_standard_template (queue_id, standard_template_id, create_by, create_time, change_by, change_time)
    VALUES
    (2, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table queue_standard_template
-- ----------------------------------------------------------
INSERT INTO queue_standard_template (queue_id, standard_template_id, create_by, create_time, change_by, change_time)
    VALUES
    (3, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table queue_standard_template
-- ----------------------------------------------------------
INSERT INTO queue_standard_template (queue_id, standard_template_id, create_by, create_time, change_by, change_time)
    VALUES
    (4, 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table auto_response_type
-- ----------------------------------------------------------
INSERT INTO auto_response_type (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('auto reply', 'Automatic reply which will be sent out after a new ticket has been created.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table auto_response_type
-- ----------------------------------------------------------
INSERT INTO auto_response_type (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('auto reject', 'Automatic reject which will be sent out after a follow-up has been rejected (in case queue follow-up option is "reject").', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table auto_response_type
-- ----------------------------------------------------------
INSERT INTO auto_response_type (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('auto follow up', 'Automatic confirmation which is sent out after a follow-up has been received for a ticket (in case queue follow-up option is "possible").', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table auto_response_type
-- ----------------------------------------------------------
INSERT INTO auto_response_type (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('auto reply/new ticket', 'Automatic response which will be sent out after a follow-up has been rejected and a new ticket has been created (in case queue follow-up option is "new ticket").', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table auto_response_type
-- ----------------------------------------------------------
INSERT INTO auto_response_type (name, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('auto remove', 'Auto remove will be sent out after a customer removed the request.', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table auto_response
-- ----------------------------------------------------------
INSERT INTO auto_response (type_id, system_address_id, name, text0, text1, content_type, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (1, 1, 'default reply (after new ticket has been created)', 'This is a demo text which is send to every inquiry.
It could contain something like:

Thanks for your email. A new ticket has been created.

You wrote:
<OTRS_CUSTOMER_EMAIL[6]>

Your email will be answered by a human ASAP

Have fun with OTRS! :-)

Your OTRS Team
', 'RE: <OTRS_CUSTOMER_SUBJECT[24]>', 'text/plain', '', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table auto_response
-- ----------------------------------------------------------
INSERT INTO auto_response (type_id, system_address_id, name, text0, text1, content_type, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (2, 1, 'default reject (after follow-up and rejected of a closed ticket)', 'Your previous ticket is closed.

-- Your follow-up has been rejected. --

Please create a new ticket.

Your OTRS Team
', 'Your email has been rejected! (RE: <OTRS_CUSTOMER_SUBJECT[24]>)', 'text/plain', '', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table auto_response
-- ----------------------------------------------------------
INSERT INTO auto_response (type_id, system_address_id, name, text0, text1, content_type, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (3, 1, 'default follow-up (after a ticket follow-up has been added)', 'Thanks for your follow-up email

You wrote:
<OTRS_CUSTOMER_EMAIL[6]>

Your email will be answered by a human ASAP.

Have fun with OTRS!

Your OTRS Team
', 'RE: <OTRS_CUSTOMER_SUBJECT[24]>', 'text/plain', '', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table auto_response
-- ----------------------------------------------------------
INSERT INTO auto_response (type_id, system_address_id, name, text0, text1, content_type, comments, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (4, 1, 'default reject/new ticket created (after closed follow-up with new ticket creation)', 'Your previous ticket is closed.

-- A new ticket has been created for you. --

You wrote:
<OTRS_CUSTOMER_EMAIL[6]>

Your email will be answered by a human ASAP.

Have fun with OTRS!

Your OTRS Team
', 'New ticket has been created! (RE: <OTRS_CUSTOMER_SUBJECT[24]>)', 'text/plain', '', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_type
-- ----------------------------------------------------------
INSERT INTO ticket_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Unclassified', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_type
-- ----------------------------------------------------------
INSERT INTO ticket_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('Incident', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table ticket_type
-- ----------------------------------------------------------
INSERT INTO ticket_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('Incident::Major', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table ticket_type
-- ----------------------------------------------------------
INSERT INTO ticket_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ServiceRequest', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table ticket_type
-- ----------------------------------------------------------
INSERT INTO ticket_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('Problem', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table ticket_priority
-- ----------------------------------------------------------
INSERT INTO ticket_priority (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('1 very low', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_priority
-- ----------------------------------------------------------
INSERT INTO ticket_priority (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('2 low', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_priority
-- ----------------------------------------------------------
INSERT INTO ticket_priority (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('3 normal', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_priority
-- ----------------------------------------------------------
INSERT INTO ticket_priority (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('4 high', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_priority
-- ----------------------------------------------------------
INSERT INTO ticket_priority (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('5 very high', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_lock_type
-- ----------------------------------------------------------
INSERT INTO ticket_lock_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('unlock', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_lock_type
-- ----------------------------------------------------------
INSERT INTO ticket_lock_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('lock', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_lock_type
-- ----------------------------------------------------------
INSERT INTO ticket_lock_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('tmp_lock', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('NewTicket', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('FollowUp', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('SendAutoReject', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('SendAutoReply', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('SendAutoFollowUp', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Forward', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Bounce', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('SendAnswer', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('SendAgentNotification', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('SendCustomerNotification', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('EmailAgent', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('EmailCustomer', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('PhoneCallAgent', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('PhoneCallCustomer', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('AddNote', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Move', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Lock', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Unlock', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Remove', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('TimeAccounting', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('CustomerUpdate', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('PriorityUpdate', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('OwnerUpdate', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('LoopProtection', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Misc', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('SetPendingTime', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('StateUpdate', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('TicketDynamicFieldUpdate', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('WebRequestCustomer', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('TicketLinkAdd', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('TicketLinkDelete', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('SystemRequest', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Merged', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('ResponsibleUpdate', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Subscribe', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('Unsubscribe', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('TypeUpdate', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('ServiceUpdate', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('SLAUpdate', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('ArchiveFlagUpdate', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('EscalationSolutionTimeStop', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('EscalationResponseTimeStart', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('EscalationUpdateTimeStart', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('EscalationSolutionTimeStart', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('EscalationResponseTimeNotifyBefore', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('EscalationUpdateTimeNotifyBefore', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('EscalationSolutionTimeNotifyBefore', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('EscalationResponseTimeStop', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('EscalationUpdateTimeStop', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table ticket_history_type
-- ----------------------------------------------------------
INSERT INTO ticket_history_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('TitleUpdate', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_type
-- ----------------------------------------------------------
INSERT INTO article_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('email-external', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_type
-- ----------------------------------------------------------
INSERT INTO article_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('email-internal', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_type
-- ----------------------------------------------------------
INSERT INTO article_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('email-notification-ext', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_type
-- ----------------------------------------------------------
INSERT INTO article_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('email-notification-int', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_type
-- ----------------------------------------------------------
INSERT INTO article_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('phone', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_type
-- ----------------------------------------------------------
INSERT INTO article_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('fax', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_type
-- ----------------------------------------------------------
INSERT INTO article_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('sms', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_type
-- ----------------------------------------------------------
INSERT INTO article_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('webrequest', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_type
-- ----------------------------------------------------------
INSERT INTO article_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('note-internal', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_type
-- ----------------------------------------------------------
INSERT INTO article_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('note-external', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_type
-- ----------------------------------------------------------
INSERT INTO article_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('note-report', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_type
-- ----------------------------------------------------------
INSERT INTO article_type (name, comments, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('note-supplier-external', 'created by ExternalSupplierForwarding installation', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table article_type
-- ----------------------------------------------------------
INSERT INTO article_type (name, comments, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('note-supplier-internal', 'created by ExternalSupplierForwarding installation', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table article_sender_type
-- ----------------------------------------------------------
INSERT INTO article_sender_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('agent', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_sender_type
-- ----------------------------------------------------------
INSERT INTO article_sender_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('system', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table article_sender_type
-- ----------------------------------------------------------
INSERT INTO article_sender_type (name, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    ('customer', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Ticket create notification', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (1, 'VisibleForAgent', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (1, 'VisibleForAgentTooltip', 'You will receive a notification each time a new ticket is created in one of your "My Queues" or "My Services".');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (1, 'Events', 'NotificationNewTicket');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (1, 'Recipients', 'AgentMyQueues');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (1, 'Recipients', 'AgentMyServices');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (1, 'SendOnOutOfOffice', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (1, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (1, 'AgentEnabledByDefault', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Ticket follow-up notification (unlocked)', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (2, 'VisibleForAgent', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (2, 'VisibleForAgentTooltip', 'You will receive a notification if a customer sends a follow-up to an unlocked ticket which is in your "My Queues" or "My Services".');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (2, 'Events', 'NotificationFollowUp');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (2, 'Recipients', 'AgentOwner');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (2, 'Recipients', 'AgentWatcher');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (2, 'Recipients', 'AgentMyQueues');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (2, 'Recipients', 'AgentMyServices');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (2, 'SendOnOutOfOffice', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (2, 'LockID', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (2, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (2, 'AgentEnabledByDefault', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Ticket follow-up notification (locked)', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (3, 'VisibleForAgent', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (3, 'VisibleForAgentTooltip', 'You will receive a notification if a customer sends a follow-up to a locked ticket of which you are the ticket owner or responsible.');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (3, 'Events', 'NotificationFollowUp');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (3, 'Recipients', 'AgentOwner');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (3, 'Recipients', 'AgentResponsible');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (3, 'Recipients', 'AgentWatcher');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (3, 'SendOnOutOfOffice', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (3, 'LockID', '2');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (3, 'LockID', '3');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (3, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (3, 'AgentEnabledByDefault', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Ticket lock timeout notification', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (4, 'VisibleForAgent', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (4, 'VisibleForAgentTooltip', 'You will receive a notification as soon as a ticket owned by you is automatically unlocked.');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (4, 'Events', 'NotificationLockTimeout');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (4, 'Recipients', 'AgentOwner');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (4, 'SendOnOutOfOffice', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (4, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (4, 'AgentEnabledByDefault', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Ticket owner update notification', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (5, 'Events', 'NotificationOwnerUpdate');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (5, 'Recipients', 'AgentOwner');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (5, 'SendOnOutOfOffice', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (5, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Ticket responsible update notification', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (6, 'Events', 'NotificationResponsibleUpdate');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (6, 'Recipients', 'AgentResponsible');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (6, 'SendOnOutOfOffice', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (6, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Ticket new note notification', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (7, 'Events', 'NotificationAddNote');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (7, 'Recipients', 'AgentOwner');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (7, 'Recipients', 'AgentResponsible');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (7, 'Recipients', 'AgentWatcher');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (7, 'SendOnOutOfOffice', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (7, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Ticket queue update notification', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (8, 'VisibleForAgent', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (8, 'VisibleForAgentTooltip', 'You will receive a notification if a ticket is moved into one of your "My Queues".');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (8, 'Events', 'NotificationMove');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (8, 'Recipients', 'AgentMyQueues');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (8, 'SendOnOutOfOffice', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (8, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (8, 'AgentEnabledByDefault', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Ticket pending reminder notification (locked)', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (9, 'Events', 'NotificationPendingReminder');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (9, 'Recipients', 'AgentOwner');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (9, 'Recipients', 'AgentResponsible');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (9, 'SendOnOutOfOffice', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (9, 'OncePerDay', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (9, 'LockID', '2');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (9, 'LockID', '3');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (9, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Ticket pending reminder notification (unlocked)', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (10, 'Events', 'NotificationPendingReminder');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (10, 'Recipients', 'AgentOwner');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (10, 'Recipients', 'AgentResponsible');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (10, 'Recipients', 'AgentMyQueues');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (10, 'SendOnOutOfOffice', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (10, 'OncePerDay', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (10, 'LockID', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (10, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Ticket escalation notification', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (11, 'Events', 'NotificationEscalation');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (11, 'Recipients', 'AgentMyQueues');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (11, 'Recipients', 'AgentWritePermissions');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (11, 'SendOnOutOfOffice', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (11, 'OncePerDay', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (11, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Ticket escalation warning notification', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (12, 'Events', 'NotificationEscalationNotifyBefore');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (12, 'Recipients', 'AgentMyQueues');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (12, 'Recipients', 'AgentWritePermissions');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (12, 'SendOnOutOfOffice', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (12, 'OncePerDay', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (12, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Ticket service update notification', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (13, 'VisibleForAgent', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (13, 'VisibleForAgentTooltip', 'You will receive a notification if a ticket''s service is changed to one of your "My Services".');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (13, 'Events', 'NotificationServiceUpdate');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (13, 'Recipients', 'AgentMyServices');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (13, 'SendOnOutOfOffice', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (13, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (13, 'AgentEnabledByDefault', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Linked Person Notification (Agent)', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'AgentEnabledByDefault', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'ArticleAttachmentInclude', '0');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'ArticleSenderTypeID', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'ArticleSenderTypeID', '3');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'ArticleTypeID', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'ArticleTypeID', '2');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'ArticleTypeID', '3');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'ArticleTypeID', '4');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'ArticleTypeID', '5');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'ArticleTypeID', '9');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'ArticleTypeID', '10');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'Events', 'ArticleCreate');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'NotificationArticleTypeID', '3');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'Recipients', 'LinkedPerson');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'TransportEmailTemplate', 'Default');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (14, 'VisibleForAgent', '0');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Linked Person Notification (Customer)', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'AgentEnabledByDefault', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'ArticleAttachmentInclude', '0');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'ArticleSenderTypeID', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'ArticleSenderTypeID', '3');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'ArticleTypeID', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'ArticleTypeID', '3');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'ArticleTypeID', '5');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'ArticleTypeID', '10');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'Events', 'ArticleCreate');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'NotificationArticleTypeID', '3');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'Recipients', 'LinkedPersonCustomer');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'TransportEmailTemplate', 'Default');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (15, 'VisibleForAgent', '0');
-- ----------------------------------------------------------
--  insert into table notification_event
-- ----------------------------------------------------------
INSERT INTO notification_event (name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Linked Person Notification (3rd Person)', 1, '', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'AgentEnabledByDefault', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'ArticleAttachmentInclude', '0');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'ArticleSenderTypeID', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'ArticleSenderTypeID', '3');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'ArticleTypeID', '1');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'ArticleTypeID', '3');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'ArticleTypeID', '5');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'ArticleTypeID', '10');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'Events', 'ArticleCreate');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'NotificationArticleTypeID', '3');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'Recipients', 'LinkedPerson3rdPerson');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'TransportEmailTemplate', 'Default');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'Transports', 'Email');
-- ----------------------------------------------------------
--  insert into table notification_event_item
-- ----------------------------------------------------------
INSERT INTO notification_event_item (notification_id, event_key, event_value)
    VALUES
    (16, 'VisibleForAgent', '0');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (1, 'text/plain', 'en', 'Ticket Created: <OTRS_TICKET_Title>', 'Hi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] has been created in queue <OTRS_TICKET_Queue>.

<OTRS_CUSTOMER_REALNAME> wrote:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (2, 'text/plain', 'en', 'Unlocked Ticket Follow-Up: <OTRS_CUSTOMER_SUBJECT[24]>', 'Hi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

the unlocked ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] received a follow-up.

<OTRS_CUSTOMER_REALNAME> wrote:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (3, 'text/plain', 'en', 'Locked Ticket Follow-Up: <OTRS_CUSTOMER_SUBJECT[24]>', 'Hi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

the locked ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] received a follow-up.

<OTRS_CUSTOMER_REALNAME> wrote:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (4, 'text/plain', 'en', 'Ticket Lock Timeout: <OTRS_TICKET_Title>', 'Hi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] has reached its lock timeout period and is now unlocked.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (5, 'text/plain', 'en', 'Ticket Owner Update to <OTRS_OWNER_UserFullname>: <OTRS_TICKET_Title>', 'Hi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

the owner of ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] has been updated to <OTRS_TICKET_OWNER_UserFullname> by <OTRS_CURRENT_UserFullname>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (6, 'text/plain', 'en', 'Ticket Responsible Update to <OTRS_RESPONSIBLE_UserFullname>: <OTRS_TICKET_Title>', 'Hi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

the responsible agent of ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] has been updated to <OTRS_TICKET_RESPONSIBLE_UserFullname> by <OTRS_CURRENT_UserFullname>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (7, 'text/plain', 'en', 'Ticket Note: <OTRS_AGENT_SUBJECT[24]>', 'Hi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

<OTRS_CURRENT_UserFullname> wrote:
<OTRS_AGENT_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (8, 'text/plain', 'en', 'Ticket Queue Update to <OTRS_TICKET_Queue>: <OTRS_TICKET_Title>', 'Hi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] has been updated to queue <OTRS_TICKET_Queue>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (9, 'text/plain', 'en', 'Locked Ticket Pending Reminder Time Reached: <OTRS_TICKET_Title>', 'Hi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

the pending reminder time of the locked ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] has been reached.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (10, 'text/plain', 'en', 'Unlocked Ticket Pending Reminder Time Reached: <OTRS_TICKET_Title>', 'Hi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

the pending reminder time of the unlocked ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] has been reached.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (11, 'text/plain', 'en', 'Ticket Escalation! <OTRS_TICKET_Title>', 'Hi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] is escalated!

Escalated at: <OTRS_TICKET_EscalationDestinationDate>
Escalated since: <OTRS_TICKET_EscalationDestinationIn>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (12, 'text/plain', 'en', 'Ticket Escalation Warning! <OTRS_TICKET_Title>', 'Hi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] will escalate!

Escalation at: <OTRS_TICKET_EscalationDestinationDate>
Escalation in: <OTRS_TICKET_EscalationDestinationIn>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>


-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (13, 'text/plain', 'en', 'Ticket Service Update to <OTRS_TICKET_Service>: <OTRS_TICKET_Title>', 'Hi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

the service of ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] has been updated to <OTRS_TICKET_Service>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (1, 'text/plain', 'de', 'Ticket erstellt: <OTRS_TICKET_Title>', 'Hallo <OTRS_NOTIFICATION_RECIPIENT_UserFirstname> <OTRS_NOTIFICATION_RECIPIENT_UserLastname>,

das Ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] wurde in der Queue <OTRS_TICKET_Queue> erstellt.

<OTRS_CUSTOMER_REALNAME> schrieb:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (2, 'text/plain', 'de', 'Nachfrage zum freigegebenen Ticket: <OTRS_CUSTOMER_SUBJECT[24]>', 'Hallo <OTRS_NOTIFICATION_RECIPIENT_UserFirstname> <OTRS_NOTIFICATION_RECIPIENT_UserLastname>,

zum freigegebenen Ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] gibt es eine Nachfrage.

<OTRS_CUSTOMER_REALNAME> schrieb:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (3, 'text/plain', 'de', 'Nachfrage zum gesperrten Ticket: <OTRS_CUSTOMER_SUBJECT[24]>', 'Hallo <OTRS_NOTIFICATION_RECIPIENT_UserFirstname> <OTRS_NOTIFICATION_RECIPIENT_UserLastname>,

zum gesperrten Ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] gibt es eine Nachfrage.

<OTRS_CUSTOMER_REALNAME> schrieb:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (4, 'text/plain', 'de', 'Ticketsperre aufgehoben: <OTRS_TICKET_Title>', 'Hallo <OTRS_NOTIFICATION_RECIPIENT_UserFirstname> <OTRS_NOTIFICATION_RECIPIENT_UserLastname>,

die Sperrzeit des Tickets [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] ist abgelaufen. Es ist jetzt freigegeben.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (5, 'text/plain', 'de', 'Änderung des Ticket-Besitzers auf <OTRS_OWNER_UserFullname>: <OTRS_TICKET_Title>', 'Hallo <OTRS_NOTIFICATION_RECIPIENT_UserFirstname> <OTRS_NOTIFICATION_RECIPIENT_UserLastname>,

der Besitzer des Tickets [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] wurde von <OTRS_CURRENT_UserFullname> geändert auf <OTRS_TICKET_OWNER_UserFullname>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (6, 'text/plain', 'de', 'Änderung des Ticket-Verantwortlichen auf <OTRS_RESPONSIBLE_UserFullname>: <OTRS_TICKET_Title>', 'Hallo <OTRS_NOTIFICATION_RECIPIENT_UserFirstname> <OTRS_NOTIFICATION_RECIPIENT_UserLastname>,

der Verantwortliche für das Ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] wurde von <OTRS_CURRENT_UserFullname> geändert auf <OTRS_TICKET_RESPONSIBLE_UserFullname>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (7, 'text/plain', 'de', 'Ticket-Notiz: <OTRS_AGENT_SUBJECT[24]>', 'Hallo <OTRS_NOTIFICATION_RECIPIENT_UserFirstname> <OTRS_NOTIFICATION_RECIPIENT_UserLastname>,

<OTRS_CURRENT_UserFullname> schrieb:
<OTRS_AGENT_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (8, 'text/plain', 'de', 'Ticket-Queue geändert zu <OTRS_TICKET_Queue>: <OTRS_TICKET_Title>', 'Hallo <OTRS_NOTIFICATION_RECIPIENT_UserFirstname> <OTRS_NOTIFICATION_RECIPIENT_UserLastname>,

das Ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] wurde in die Queue <OTRS_TICKET_Queue> verschoben.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (9, 'text/plain', 'de', 'Erinnerungszeit des gesperrten Tickets erreicht: <OTRS_TICKET_Title>', 'Hallo <OTRS_NOTIFICATION_RECIPIENT_UserFirstname> <OTRS_NOTIFICATION_RECIPIENT_UserLastname>,

die Erinnerungszeit für das gesperrte Ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] wurde erreicht.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (10, 'text/plain', 'de', 'Erinnerungszeit des freigegebenen Tickets erreicht: <OTRS_TICKET_Title>', 'Hallo <OTRS_NOTIFICATION_RECIPIENT_UserFirstname> <OTRS_NOTIFICATION_RECIPIENT_UserLastname>,

die Erinnerungszeit für das freigegebene Ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] wurde erreicht.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (11, 'text/plain', 'de', 'Ticket-Eskalation! <OTRS_TICKET_Title>', 'Hallo <OTRS_NOTIFICATION_RECIPIENT_UserFirstname> <OTRS_NOTIFICATION_RECIPIENT_UserLastname>,

das Ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] ist eskaliert!

Eskaliert am: <OTRS_TICKET_EscalationDestinationDate>
Eskaliert seit: <OTRS_TICKET_EscalationDestinationIn>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (12, 'text/plain', 'de', 'Ticket-Eskalations-Warnung! <OTRS_TICKET_Title>', 'Hallo <OTRS_NOTIFICATION_RECIPIENT_UserFirstname> <OTRS_NOTIFICATION_RECIPIENT_UserLastname>,

das Ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] wird bald eskalieren!

Eskalation um: <OTRS_TICKET_EscalationDestinationDate>
Eskalation in: <OTRS_TICKET_EscalationDestinationIn>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>


-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (13, 'text/plain', 'de', 'Ticket-Service aktualisiert zu <OTRS_TICKET_Service>: <OTRS_TICKET_Title>', 'Hallo <OTRS_NOTIFICATION_RECIPIENT_UserFirstname> <OTRS_NOTIFICATION_RECIPIENT_UserLastname>,

der Service des Tickets [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] wurde geändert zu <OTRS_TICKET_Service>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (1, 'text/plain', 'es_MX', 'Se ha creado un ticket: <OTRS_TICKET_Title>', 'Hola <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

el ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] se ha creado en la fila <OTRS_TICKET_Queue>.

<OTRS_CUSTOMER_REALNAME> escribió:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (2, 'text/plain', 'es_MX', 'Seguimiento a ticket desbloqueado: <OTRS_CUSTOMER_SUBJECT[24]>', 'Hola <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

el ticket desbloqueado [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] recibió un seguimiento.

<OTRS_CUSTOMER_REALNAME> escribió:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (3, 'text/plain', 'es_MX', 'Seguimiento a ticket bloqueado: <OTRS_CUSTOMER_SUBJECT[24]>', 'Hola <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

el ticket bloqueado [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] recibió un seguimiento.

<OTRS_CUSTOMER_REALNAME> escribió:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (4, 'text/plain', 'es_MX', 'Terminó tiempo de bloqueo: <OTRS_TICKET_Title>', 'Hola <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

el ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>]  ha alcanzado su tiempo de espera como bloqueado y ahora se encuentra desbloqueado.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (5, 'text/plain', 'es_MX', 'Actualización del propietario de ticket a <OTRS_OWNER_UserFullname>: <OTRS_TICKET_Title>', 'Hola <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

el propietario del ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] se ha modificado  a <OTRS_TICKET_OWNER_UserFullname> por <OTRS_CURRENT_UserFullname>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (6, 'text/plain', 'es_MX', 'Actualización del responsable de ticket a <OTRS_RESPONSIBLE_UserFullname>: <OTRS_TICKET_Title>', 'Hola <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

el agente responsable del ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] se ha modificado a <OTRS_TICKET_RESPONSIBLE_UserFullname> por <OTRS_CURRENT_UserFullname>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (7, 'text/plain', 'es_MX', 'Nota de ticket: <OTRS_AGENT_SUBJECT[24]>', 'Hola <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

<OTRS_CURRENT_UserFullname> escribió:
<OTRS_AGENT_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (8, 'text/plain', 'es_MX', 'La fila del ticket ha cambiado a <OTRS_TICKET_Queue>: <OTRS_TICKET_Title>', 'Hola <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

el ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] ha cambiado de fila a <OTRS_TICKET_Queue>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (9, 'text/plain', 'es_MX', 'Recordatorio pendiente en ticket bloqueado se ha alcanzado: <OTRS_TICKET_Title>', 'Hola <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

el tiempo del recordatorio pendiente para el ticket bloqueado [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] se ha alcanzado.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (10, 'text/plain', 'es_MX', 'Recordatorio pendiente en ticket desbloqueado se ha alcanzado: <OTRS_TICKET_Title>', 'Hola <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

el tiempo del recordatorio pendiente para el ticket desbloqueado [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] se ha alcanzado.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (11, 'text/plain', 'es_MX', '¡Escalación de ticket! <OTRS_TICKET_Title>', 'Hola <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

el ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] se ha escalado!

Escaló: <OTRS_TICKET_EscalationDestinationDate>
Escalado desde: <OTRS_TICKET_EscalationDestinationIn>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (12, 'text/plain', 'es_MX', 'Aviso de escalación de ticket! <OTRS_TICKET_Title>', 'Hola <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

el ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] se encuentra proximo a escalar!

Escalará: <OTRS_TICKET_EscalationDestinationDate>
Escalará en: <OTRS_TICKET_EscalationDestinationIn>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>


-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (13, 'text/plain', 'es_MX', 'El servicio del ticket ha cambiado a <OTRS_TICKET_Service>: <OTRS_TICKET_Title>', 'Hola <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

el servicio del ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] se ha cambiado a <OTRS_TICKET_Service>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (1, 'text/plain', 'zh_CN', '票据编制 工单已创建：<OTRS_TICKET_Title>', '您好 <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

票据工单 [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] 已在等待队列 已在队列<OTRS_TICKET_Queue> 中被编制完成。中被创建完成

<OTRS_CUSTOMER_REALNAME> 写道：
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (2, 'text/plain', 'zh_CN', '解锁票据的后续作业解锁工单的后续： <OTRS_CUSTOMER_SUBJECT[24]>', '您好<OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

解锁票据解锁工单[<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] 已获得一项后续作业。

<OTRS_CUSTOMER_REALNAME> 写道:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (3, 'text/plain', 'zh_CN', '加锁票据的后续作业 锁定工单后续：<OTRS_CUSTOMER_SUBJECT[24]>', '您好 <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

加锁票据锁定工单 [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] 已获得一项后续作业。

<OTRS_CUSTOMER_REALNAME> 写道：
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (4, 'text/plain', 'zh_CN', '票据加锁超时工单锁定超时：<OTRS_TICKET_Title>', '您好 <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

票据工单 [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] 已达到其锁定时限，现在解锁。

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (5, 'text/plain', 'zh_CN', '票据的拥有人升级为工单所有者更新为 <OTRS_OWNER_UserFullname>: <OTRS_TICKET_Title>', '您好 <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

票据的所有人工单的所有者 [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] 已被该信为 <OTRS_TICKET_OWNER_UserFullname> 的 <OTRS_CURRENT_UserFullname>。

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (6, 'text/plain', 'zh_CN', '票据的负责人 工单负责人更新为<OTRS_RESPONSIBLE_UserFullname>: <OTRS_TICKET_Title>', '您好 <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

工单的负责人 [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] 已被升级为 已被更新为 <OTRS_TICKET_RESPONSIBLE_UserFullname> 的 <OTRS_CURRENT_UserFullname>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (7, 'text/plain', 'zh_CN', '票据备注工单备注：<OTRS_AGENT_SUBJECT[24]>', '您好 <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

<OTRS_CURRENT_UserFullname> 写道：
<OTRS_AGENT_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (8, 'text/plain', 'zh_CN', '票据序列已升级为工单队列更新为<OTRS_TICKET_Queue>: <OTRS_TICKET_Title>', '您好 <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

票据工单 [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] 已被升级为序列已被更新为队列 <OTRS_TICKET_Queue>。

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (9, 'text/plain', 'zh_CN', '已达到锁定票据即将到期的提醒时间已到达锁定工单挂起提醒时间：<OTRS_TICKET_Title>', '您好 <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

锁定票据即将到期的提醒时间锁定工单挂起提醒时间 [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] 已到达。

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (10, 'text/plain', 'zh_CN', '未锁定票据即将到期的提醒时间已到已到未锁定工单的挂起提醒时间：<OTRS_TICKET_Title>', '您好 <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

未锁定票据即将到期的提醒时间未锁定工单的挂起提醒时间 [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] 已到已到达。

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (11, 'text/plain', 'zh_CN', '票据升级！工单升级！<OTRS_TICKET_Title>', '您好 <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

票据工单 [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] 已被升级！

升级地点升级开始时间：<OTRS_TICKET_EscalationDestinationDate>
升级开始时间升级在：<OTRS_TICKET_EscalationDestinationIn>内

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (12, 'text/plain', 'zh_CN', '工单升级警告Ticket Escalation Warning! <OTRS_TICKET_Title>', '您好  <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

票据工单 [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] 将升级！

升级地点升级开始时间：<OTRS_TICKET_EscalationDestinationDate>
升级开始时间升级在：<OTRS_TICKET_EscalationDestinationIn>内

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>


-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (13, 'text/plain', 'zh_CN', '票据服务升级为工单服务更新为<OTRS_TICKET_Service>: <OTRS_TICKET_Title>', '您好 <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

票据服务工单服务 [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] 已被升级为已被更新为 <OTRS_TICKET_Service>。

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (1, 'text/plain', 'pt_BR', 'Ticket criado: <OTRS_TICKET_Title>', 'Oi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

o ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] foi criado na fila <OTRS_TICKET_Queue>.

<OTRS_CUSTOMER_REALNAME> escreveu:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (2, 'text/plain', 'pt_BR', 'Acompanhamento do ticket desbloqueado: <OTRS_CUSTOMER_SUBJECT[24]>', 'Oi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

o ticket desbloqueado [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] recebeu uma resposta.

<OTRS_CUSTOMER_REALNAME> escreveu:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (3, 'text/plain', 'pt_BR', 'Acompanhamento do ticket bloqueado: <OTRS_CUSTOMER_SUBJECT[24]>', 'Oi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

o ticket bloqueado [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] recebeu uma resposta.

<OTRS_CUSTOMER_REALNAME> escreveu:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (4, 'text/plain', 'pt_BR', 'Tempo limite de bloqueio do ticket: <OTRS_TICKET_Title>', 'Oi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

o ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] atingiu o seu período de tempo limite de bloqueio e agora está desbloqueado.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (5, 'text/plain', 'pt_BR', 'Atualização de proprietário de ticket para <OTRS_OWNER_UserFullname>: <OTRS_TICKET_Title>', 'Oi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

o proprietário do ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] foi atualizado para <OTRS_TICKET_OWNER_UserFullname> por <OTRS_CURRENT_UserFullname>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (6, 'text/plain', 'pt_BR', 'Atualização de responsável de ticket para <OTRS_RESPONSIBLE_UserFullname>: <OTRS_TICKET_Title>', 'Oi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

o agente responsável do ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] foi atualizado para <OTRS_TICKET_RESPONSIBLE_UserFullname> por <OTRS_CURRENT_UserFullname>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (7, 'text/plain', 'pt_BR', 'Observação sobre o ticket: <OTRS_AGENT_SUBJECT[24]>', 'Oi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

<OTRS_CURRENT_UserFullname> escreveu:
<OTRS_AGENT_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (8, 'text/plain', 'pt_BR', 'Atualização da fila do ticket para <OTRS_TICKET_Queue>: <OTRS_TICKET_Title>', 'Oi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

o ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] foi atualizado na fila <OTRS_TICKET_Queue>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (9, 'text/plain', 'pt_BR', 'Tempo de Lembrete de Pendência do Ticket Bloqueado Atingido: <OTRS_TICKET_Title>', 'Oi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

o tempo de lembrete pendente do ticket bloqueado [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] foi atingido.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (10, 'text/plain', 'pt_BR', 'Tempo de Lembrete Pendente do Ticket Desbloqueado Atingido: <OTRS_TICKET_Title>', 'Oi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

o tempo de lembrete pendente do ticket desbloqueado [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] foi atingido.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (11, 'text/plain', 'pt_BR', 'Escalonamento do ticket! <OTRS_TICKET_Title>', 'Oi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

o ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] foi escalonado!

Escalonado em: <OTRS_TICKET_EscalationDestinationDate>
Escalonado desde: <OTRS_TICKET_EscalationDestinationIn>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (12, 'text/plain', 'pt_BR', 'Aviso de escalonamento do ticket! <OTRS_TICKET_Title>', 'Oi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

o ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] será escalonado!

Escalonamento em: <OTRS_TICKET_EscalationDestinationDate>
Escalonamento em: <OTRS_TICKET_EscalationDestinationIn>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>


-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (13, 'text/plain', 'pt_BR', 'Atualização do serviço do ticket para <OTRS_TICKET_Service>: <OTRS_TICKET_Title>', 'Oi <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>,

o serviço do ticket [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] foi atualizado para <OTRS_TICKET_Service>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (1, 'text/plain', 'hu', 'Jegy létrehozva: <OTRS_TICKET_Title>', 'Kedves <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>!

A(z) [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] jegy létrejött a következő várólistában: <OTRS_TICKET_Queue>.

<OTRS_CUSTOMER_REALNAME> ezt írta:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (2, 'text/plain', 'hu', 'Feloldott jegy követése: <OTRS_CUSTOMER_SUBJECT[24]>', 'Kedves <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>!

A feloldott [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] jegy egy követő üzenetet kapott.

<OTRS_CUSTOMER_REALNAME> ezt írta:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (3, 'text/plain', 'hu', 'Zárolt jegy követése: <OTRS_CUSTOMER_SUBJECT[24]>', 'Kedves <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>!

A zárolt [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] jegy egy követő üzenetet kapott.

<OTRS_CUSTOMER_REALNAME> ezt írta:
<OTRS_CUSTOMER_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (4, 'text/plain', 'hu', 'Jegyzár időkorlát: <OTRS_TICKET_Title>', 'Kedves <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>!

A(z) [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] jegy elérte a zárolás időkorlátjának időtartamát, és most feloldásra került.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (5, 'text/plain', 'hu', 'Jegytulajdonos frissítés <OTRS_OWNER_UserLastname> <OTRS_OWNER_UserFirstname> ügyintézőre: <OTRS_TICKET_Title>', 'Kedves <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>!

A(z) [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] jegy tulajdonosát <OTRS_CURRENT_UserLastname> <OTRS_CURRENT_UserFirstname> frissítette <OTRS_OWNER_UserLastname> <OTRS_OWNER_UserFirstname> ügyintézőre.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (6, 'text/plain', 'hu', 'Jegyfelelős frissítés <OTRS_RESPONSIBLE_UserLastname> <OTRS_RESPONSIBLE_UserFirstname> ügyintézőre: <OTRS_TICKET_Title>', 'Kedves <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>!

A(z) [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] jegy felelős ügyintézőjét <OTRS_CURRENT_UserLastname> <OTRS_CURRENT_UserFirstname> frissítette <OTRS_RESPONSIBLE_UserLastname> <OTRS_RESPONSIBLE_UserFirstname> ügyintézőre.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (7, 'text/plain', 'hu', 'Új jegyzet: <OTRS_AGENT_SUBJECT[24]>', 'Kedves <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>!

<OTRS_CURRENT_UserLastname> <OTRS_CURRENT_UserFirstname> ezt írta:
<OTRS_AGENT_BODY[30]>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (8, 'text/plain', 'hu', 'Jegy várólista frissítés <OTRS_TICKET_Queue> várólistára: <OTRS_TICKET_Title>', 'Kedves <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>!

A(z) [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] jegyet áthelyezték a következő várólistába: <OTRS_TICKET_Queue>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (9, 'text/plain', 'hu', 'Zárolt jegy „emlékeztető függőben” ideje elérve: <OTRS_TICKET_Title>', 'Kedves <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>!

A zárolt [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] jegy elérte az „emlékeztető függőben” idejét.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (10, 'text/plain', 'hu', 'Feloldott jegy „emlékeztető függőben” ideje elérve: <OTRS_TICKET_Title>', 'Kedves <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>!

A feloldott [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] jegy elérte az „emlékeztető függőben” idejét.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (11, 'text/plain', 'hu', 'Jegyeszkaláció! <OTRS_TICKET_Title>', 'Kedves <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>!

A(z) [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] jegy eszkalálódott!

Eszkaláció időpontja: <OTRS_TICKET_EscalationDestinationDate>
Eszkaláció óta eltelt idő: <OTRS_TICKET_EscalationDestinationIn>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (12, 'text/plain', 'hu', 'Jegyeszkaláció figyelmeztetés! <OTRS_TICKET_Title>', 'Kedves <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>!

A(z) [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] jegy eszkalálódni fog!

Eszkaláció időpontja: <OTRS_TICKET_EscalationDestinationDate>
Eszkalációig fennmaradó idő: <OTRS_TICKET_EscalationDestinationIn>

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>


-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (13, 'text/plain', 'hu', 'Jegyszolgáltatás frissítve <OTRS_TICKET_Service> szolgáltatásra: <OTRS_TICKET_Title>', 'Kedves <OTRS_NOTIFICATION_RECIPIENT_UserFirstname>!

A(z) [<OTRS_CONFIG_Ticket::Hook><OTRS_CONFIG_Ticket::HookDivider><OTRS_TICKET_TicketNumber>] jegy szolgáltatása frissítve lett a következőre: <OTRS_TICKET_Service>.

<OTRS_CONFIG_HttpType>://<OTRS_CONFIG_FQDN>/<OTRS_CONFIG_ScriptAlias>index.pl?Action=AgentTicketZoom;TicketID=<OTRS_TICKET_TicketID>

-- <OTRS_CONFIG_NotificationSenderName>');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (14, 'text/html', 'de', 'BENACHRICHTIGUNG! <OTRS_CUSTOMER_SUBJECT[24]> [<OTRS_CONFIG_Ticket::Hook><OTRS_TICKET_TicketNumber>]', 'Hallo,<br /><br />"&lt;OTRS_CURRENT_UserFirstname&gt; &lt;OTRS_CURRENT_UserLastname&gt;" hat folgende Notiz an Ticket &lt;OTRS_TICKET_TicketNumber&gt; angehangen.<br /><br />----------------------<br />&lt;OTRS_CUSTOMER_BODY&gt;<br />----------------------<br /><br />Diese Benachrichtigung wurde Ihnen im Auftrag von "&lt;OTRS_CURRENT_UserFirstname&gt; &lt;OTRS_CURRENT_UserLastname&gt;" zugesendet.<br /><br />&lt;OTRS_CONFIG_HttpType&gt;://&lt;OTRS_CONFIG_FQDN&gt;/&lt;OTRS_CONFIG_ScriptAlias&gt;index.pl?Action=AgentZoom&TicketID=&lt;OTRS_TICKET_TicketID&gt;');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (14, 'text/html', 'en', 'NOTIFICATION! <OTRS_CUSTOMER_SUBJECT[24]> [<OTRS_CONFIG_Ticket::Hook><OTRS_TICKET_TicketNumber>]', 'Hello,<br /><br />"&lt;OTRS_CURRENT_UserFirstname&gt; &lt;OTRS_CURRENT_UserLastname&gt;" has added following notice to ticket &lt;OTRS_TICKET_TicketNumber&gt;.<br /><br />----------------------<br />&lt;OTRS_CUSTOMER_BODY&gt;<br />----------------------<br /><br />This notification was sent to you, because "&lt;OTRS_CURRENT_UserFirstname&gt; &lt;OTRS_CURRENT_UserLastname&gt;" wants to inform you about this process.<br /><br />&lt;OTRS_CONFIG_HttpType&gt;://&lt;OTRS_CONFIG_FQDN&gt;/&lt;OTRS_CONFIG_ScriptAlias&gt;index.pl?Action=AgentZoom&TicketID=&lt;OTRS_TICKET_TicketID&gt;');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (15, 'text/html', 'de', 'BENACHRICHTIGUNG! <OTRS_CUSTOMER_SUBJECT[24]> [<OTRS_CONFIG_Ticket::Hook><OTRS_TICKET_TicketNumber>]', 'Hallo,<br /><br />"&lt;OTRS_CURRENT_UserFirstname&gt; &lt;OTRS_CURRENT_UserLastname&gt;" hat folgende Notiz an Ticket &lt;OTRS_TICKET_TicketNumber&gt; angehangen.<br /><br />----------------------<br />&lt;OTRS_CUSTOMER_BODY&gt;<br />----------------------<br /><br />Diese Benachrichtigung wurde Ihnen im Auftrag von "&lt;OTRS_CURRENT_UserFirstname&gt; &lt;OTRS_CURRENT_UserLastname&gt;" zugesendet.<br /><br />&lt;OTRS_CONFIG_HttpType&gt;://&lt;OTRS_CONFIG_FQDN&gt;/&lt;OTRS_CONFIG_ScriptAlias&gt;index.pl?Action=AgentZoom&TicketID=&lt;OTRS_TICKET_TicketID&gt;');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (15, 'text/html', 'en', 'NOTIFICATION! <OTRS_CUSTOMER_SUBJECT[24]> [<OTRS_CONFIG_Ticket::Hook><OTRS_TICKET_TicketNumber>]', 'Hello,<br /><br />"&lt;OTRS_CURRENT_UserFirstname&gt; &lt;OTRS_CURRENT_UserLastname&gt;" has added following notice to ticket &lt;OTRS_TICKET_TicketNumber&gt;.<br /><br />----------------------<br />&lt;OTRS_CUSTOMER_BODY&gt;<br />----------------------<br /><br />This notification was sent to you, because "&lt;OTRS_CURRENT_UserFirstname&gt; &lt;OTRS_CURRENT_UserLastname&gt;" wants to inform you about this process.<br /><br />&lt;OTRS_CONFIG_HttpType&gt;://&lt;OTRS_CONFIG_FQDN&gt;/&lt;OTRS_CONFIG_ScriptAlias&gt;index.pl?Action=AgentZoom&TicketID=&lt;OTRS_TICKET_TicketID&gt;');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (16, 'text/html', 'de', 'BENACHRICHTIGUNG! <OTRS_CUSTOMER_SUBJECT[24]> [<OTRS_CONFIG_Ticket::Hook><OTRS_TICKET_TicketNumber>]', 'Hallo,<br /><br />"&lt;OTRS_CURRENT_UserFirstname&gt; &lt;OTRS_CURRENT_UserLastname&gt;" hat folgende Notiz an Ticket &lt;OTRS_TICKET_TicketNumber&gt; angehangen.<br /><br />----------------------<br />&lt;OTRS_CUSTOMER_BODY&gt;<br />----------------------<br /><br />Diese Benachrichtigung wurde Ihnen im Auftrag von "&lt;OTRS_CURRENT_UserFirstname&gt; &lt;OTRS_CURRENT_UserLastname&gt;" zugesendet.<br /><br />&lt;OTRS_CONFIG_HttpType&gt;://&lt;OTRS_CONFIG_FQDN&gt;/&lt;OTRS_CONFIG_ScriptAlias&gt;index.pl?Action=AgentZoom&TicketID=&lt;OTRS_TICKET_TicketID&gt;');
-- ----------------------------------------------------------
--  insert into table notification_event_message
-- ----------------------------------------------------------
INSERT INTO notification_event_message (notification_id, content_type, language, subject, text)
    VALUES
    (16, 'text/html', 'en', 'NOTIFICATION! <OTRS_CUSTOMER_SUBJECT[24]> [<OTRS_CONFIG_Ticket::Hook><OTRS_TICKET_TicketNumber>]', 'Hello,<br /><br />"&lt;OTRS_CURRENT_UserFirstname&gt; &lt;OTRS_CURRENT_UserLastname&gt;" has added following notice to ticket &lt;OTRS_TICKET_TicketNumber&gt;.<br /><br />----------------------<br />&lt;OTRS_CUSTOMER_BODY&gt;<br />----------------------<br /><br />This notification was sent to you, because "&lt;OTRS_CURRENT_UserFirstname&gt; &lt;OTRS_CURRENT_UserLastname&gt;" wants to inform you about this process.<br /><br />&lt;OTRS_CONFIG_HttpType&gt;://&lt;OTRS_CONFIG_FQDN&gt;/&lt;OTRS_CONFIG_ScriptAlias&gt;index.pl?Action=AgentZoom&TicketID=&lt;OTRS_TICKET_TicketID&gt;');
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (1, 'ProcessManagementProcessID', 'Process', 2, 'ProcessID', 'Ticket', '---
DefaultValue: ''''
', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (1, 'ProcessManagementActivityID', 'Activity', 3, 'ActivityID', 'Ticket', '---
DefaultValue: ''''
', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (1, 'ITSMCriticality', 'Criticality', 4, 'Dropdown', 'Ticket', '---
DefaultValue: ''''
Link: ''''
PossibleNone: ''1''
PossibleValues:
  1 very low: 1 very low
  2 low: 2 low
  3 normal: 3 normal
  4 high: 4 high
  5 very high: 5 very high
TranslatableValues: ''1''
', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (1, 'ITSMImpact', 'Impact', 5, 'Dropdown', 'Ticket', '---
DefaultValue: 3 normal
Link: ''''
PossibleNone: ''1''
PossibleValues:
  1 very low: 1 very low
  2 low: 2 low
  3 normal: 3 normal
  4 high: 4 high
  5 very high: 5 very high
TranslatableValues: ''1''
', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (1, 'ITSMReviewRequired', 'Review Required', 6, 'Dropdown', 'Ticket', '---
DefaultValue: No
Link: ''''
PossibleNone: ''0''
PossibleValues:
  No: No
  Yes: Yes
TranslatableValues: ''1''
        ', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (1, 'ITSMDecisionResult', 'Decision Result', 7, 'Dropdown', 'Ticket', '---
DefaultValue: Pending
Link: ''''
PossibleNone: ''1''
PossibleValues:
  Approved: Approved
  Pending: Pending
  Postponed: Postponed
  Pre-approved: Pre-approved
  Rejected: Rejected
TranslatableValues: ''1''
        ', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (1, 'ITSMRepairStartTime', 'Repair Start Time', 8, 'DateTime', 'Ticket', '---
DateRestriction: ''''
DefaultValue: 0
Link: ''''
LinkPreview: ''''
YearsInFuture: ''5''
YearsInPast: ''5''
YearsPeriod: ''1''
        ', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (1, 'ITSMRecoveryStartTime', 'Recovery Start Time', 9, 'DateTime', 'Ticket', '---
DefaultValue: ''0''
Link: ''''
YearsInFuture: ''5''
YearsInPast: ''5''
YearsPeriod: ''1''
        ', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (1, 'ITSMDecisionDate', 'Decision Date', 10, 'DateTime', 'Ticket', '---
DefaultValue: ''0''
Link: ''''
YearsInFuture: ''5''
YearsInPast: ''5''
YearsPeriod: ''1''
        ', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (1, 'ITSMDueDate', 'Due Date', 11, 'DateTime', 'Ticket', '---
DefaultValue: ''259200''
Link: ''''
YearsInFuture: ''1''
YearsInPast: ''9''
YearsPeriod: ''1''
        ', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (0, 'SysMonXHost', 'SystemMonitoring HostName', 12, 'Text', 'Ticket', '---
TranslatableValues: ''1''
        ', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (0, 'SysMonXService', 'SystemMonitoring ServiceName', 13, 'Text', 'Ticket', '---
TranslatableValues: ''1''
        ', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (0, 'SysMonXAddress', 'SystemMonitoring AddressName', 14, 'Text', 'Ticket', '---
TranslatableValues: ''1''
        ', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (0, 'SysMonXAlias', 'SystemMonitoring AliasName', 15, 'Text', 'Ticket', '---
TranslatableValues: ''1''
        ', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (0, 'SysMonXState', 'SystemMonitoring StateName', 16, 'Text', 'Article', '---
DefaultValue: ''''
Link: ''''
LinkPreview: ''''
RegExList: []
        ', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (0, 'AcknowledgeName', 'SystemMonitoring AcknowledgeNameField', 17, 'Text', 'Ticket', '---
TranslatableValues: ''1''
        ', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table dynamic_field
-- ----------------------------------------------------------
INSERT INTO dynamic_field (internal_field, name, label, field_order, field_type, object_type, config, valid_id, create_by, create_time, change_by, change_time)
    VALUES
    (0, 'KIXFAQEntry', 'Suggest as FAQ-Entry', 1, 'Dropdown', 'Article', '---
DefaultValue: No
Link: ''''
LinkPreview: ''''
PossibleNone: ''0''
PossibleValues:
  No: No
  Yes: Yes
TranslatableValues: ''1''
TreeView: ''0''
        ', 1, 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table faq_language
-- ----------------------------------------------------------
INSERT INTO faq_language (name)
    VALUES
    ('en');
-- ----------------------------------------------------------
--  insert into table faq_language
-- ----------------------------------------------------------
INSERT INTO faq_language (name)
    VALUES
    ('de');
-- ----------------------------------------------------------
--  insert into table faq_state_type
-- ----------------------------------------------------------
INSERT INTO faq_state_type (name)
    VALUES
    ('internal');
-- ----------------------------------------------------------
--  insert into table faq_state_type
-- ----------------------------------------------------------
INSERT INTO faq_state_type (name)
    VALUES
    ('external');
-- ----------------------------------------------------------
--  insert into table faq_state_type
-- ----------------------------------------------------------
INSERT INTO faq_state_type (name)
    VALUES
    ('public');
-- ----------------------------------------------------------
--  insert into table faq_state
-- ----------------------------------------------------------
INSERT INTO faq_state (name, type_id)
    VALUES
    ('internal (agent)', 1);
-- ----------------------------------------------------------
--  insert into table faq_state
-- ----------------------------------------------------------
INSERT INTO faq_state (name, type_id)
    VALUES
    ('external (customer)', 2);
-- ----------------------------------------------------------
--  insert into table faq_state
-- ----------------------------------------------------------
INSERT INTO faq_state (name, type_id)
    VALUES
    ('public (all)', 3);
-- ----------------------------------------------------------
--  insert into table faq_category
-- ----------------------------------------------------------
INSERT INTO faq_category (name, comments, valid_id, created, created_by, changed, changed_by, parent_id)
    VALUES
    ('Misc', 'Misc Comment', 1, current_timestamp, 1, current_timestamp, 1, 0);
-- ----------------------------------------------------------
--  insert into table faq_history
-- ----------------------------------------------------------
INSERT INTO faq_history (name, item_id, created, created_by, changed, changed_by)
    VALUES
    ('Created', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table faq_category_group
-- ----------------------------------------------------------
INSERT INTO faq_category_group (category_id, group_id, created, created_by, changed, changed_by)
    VALUES
    (1, 4, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table faq_category_group
-- ----------------------------------------------------------
INSERT INTO faq_category_group (category_id, group_id, created, created_by, changed, changed_by)
    VALUES
    (1, 5, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table faq_category_group
-- ----------------------------------------------------------
INSERT INTO faq_category_group (category_id, group_id, created, created_by, changed, changed_by)
    VALUES
    (1, 6, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Core::IncidentState', 'Operational', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Core::IncidentState', 'Warning', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Core::IncidentState', 'Incident', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Service::Type', 'End User Service', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Service::Type', 'Front End', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Service::Type', 'Back End', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Service::Type', 'IT Management', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Service::Type', 'Reporting', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Service::Type', 'IT Operational', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Service::Type', 'Demonstration', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Service::Type', 'Project', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Service::Type', 'Training', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Service::Type', 'Underpinning Contract', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::Service::Type', 'Other', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::SLA::Type', 'Availability', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::SLA::Type', 'Response Time', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::SLA::Type', 'Recovery Time', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::SLA::Type', 'Resolution Rate', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::SLA::Type', 'Transactions', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::SLA::Type', 'Errors', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::SLA::Type', 'Other', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Class', 'Computer', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Class', 'Hardware', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Class', 'Location', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Class', 'Network', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Class', 'Software', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::DeploymentState', 'Expired', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::DeploymentState', 'Inactive', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::DeploymentState', 'Maintenance', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::DeploymentState', 'Pilot', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::DeploymentState', 'Planned', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::DeploymentState', 'Production', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::DeploymentState', 'Repair', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::DeploymentState', 'Retired', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::DeploymentState', 'Review', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::DeploymentState', 'Test/QA', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::YesNo', 'Yes', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::YesNo', 'No', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Computer::Type', 'Laptop', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Computer::Type', 'Desktop', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Computer::Type', 'Phone', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Computer::Type', 'PDA', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Computer::Type', 'Server', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Computer::Type', 'Other', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Monitor', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Printer', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Switch', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Router', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'WLAN Access Point', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Security Device', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Backup Device', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Mouse', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Keyboard', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Camera', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Beamer', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Modem', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'PCMCIA Card', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'USB Device', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Docking Station', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Scanner', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Hardware::Type', 'Other', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Location::Type', 'Building', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Location::Type', 'Office', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Location::Type', 'Floor', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Location::Type', 'Room', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Location::Type', 'Rack', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Location::Type', 'Workplace', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Location::Type', 'Outlet', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Location::Type', 'IT Facility', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Location::Type', 'Other', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Network::Type', 'LAN', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Network::Type', 'WLAN', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Network::Type', 'Telco', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Network::Type', 'GSM', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Network::Type', 'Other', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::Type', 'Client Application', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::Type', 'Middleware', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::Type', 'Server Application', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::Type', 'Client OS', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::Type', 'Server OS', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::Type', 'Admin Tool', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::Type', 'User Tool', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::Type', 'Embedded', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::Type', 'Other', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Single Licence', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Per User', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Concurrent Users', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Per Processor', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Per Server', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Per Node', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Volume Licence', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Enterprise Licence', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Developer Licence', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Demo', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Time Restricted', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Freeware', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Open Source', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog
-- ----------------------------------------------------------
INSERT INTO general_catalog (general_catalog_class, name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ITSM::ConfigItem::Software::LicenceType', 'Unlimited', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (1, 'Functionality', 'operational');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (2, 'Functionality', 'warning');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (3, 'Functionality', 'incident');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (27, 'Functionality', 'productive');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (28, 'Functionality', 'postproductive');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (29, 'Functionality', 'productive');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (30, 'Functionality', 'productive');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (31, 'Functionality', 'preproductive');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (32, 'Functionality', 'productive');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (33, 'Functionality', 'productive');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (34, 'Functionality', 'postproductive');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (35, 'Functionality', 'productive');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (36, 'Functionality', 'preproductive');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (22, 'Permission', '7');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (23, 'Permission', '7');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (24, 'Permission', '7');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (25, 'Permission', '7');
-- ----------------------------------------------------------
--  insert into table general_catalog_preferences
-- ----------------------------------------------------------
INSERT INTO general_catalog_preferences (general_catalog_id, pref_key, pref_value)
    VALUES
    (26, 'Permission', '7');
-- ----------------------------------------------------------
--  insert into table configitem_history_type
-- ----------------------------------------------------------
INSERT INTO configitem_history_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ConfigItemCreate', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_history_type
-- ----------------------------------------------------------
INSERT INTO configitem_history_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ConfigItemDelete', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_history_type
-- ----------------------------------------------------------
INSERT INTO configitem_history_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('LinkAdd', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_history_type
-- ----------------------------------------------------------
INSERT INTO configitem_history_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('LinkDelete', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_history_type
-- ----------------------------------------------------------
INSERT INTO configitem_history_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('NameUpdate', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_history_type
-- ----------------------------------------------------------
INSERT INTO configitem_history_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('VersionCreate', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_history_type
-- ----------------------------------------------------------
INSERT INTO configitem_history_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('ValueUpdate', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_history_type
-- ----------------------------------------------------------
INSERT INTO configitem_history_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('DefinitionUpdate', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_history_type
-- ----------------------------------------------------------
INSERT INTO configitem_history_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('IncidentStateUpdate', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_history_type
-- ----------------------------------------------------------
INSERT INTO configitem_history_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('DeploymentStateUpdate', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_history_type
-- ----------------------------------------------------------
INSERT INTO configitem_history_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('VersionDelete', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_history_type
-- ----------------------------------------------------------
INSERT INTO configitem_history_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('AttachmentAdd', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_history_type
-- ----------------------------------------------------------
INSERT INTO configitem_history_type (name, valid_id, create_time, create_by, change_time, change_by)
    VALUES
    ('AttachmentDelete', 1, current_timestamp, 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_definition
-- ----------------------------------------------------------
INSERT INTO configitem_definition (class_id, configitem_definition, version, create_time, create_by)
    VALUES
    (22, '[
    {
        Key => ''Vendor'',
        Name => ''Vendor'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 50,

            # Example for CI attribute syntax check for text and textarea fields
            #RegEx             => ''^ABC.*'',
            #RegExErrorMessage => ''Value must start with \"ABC\"!'',
        },
    },
    {
        Key => ''Model'',
        Name => ''Model'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 50,
        },
    },
    {
        Key => ''Description'',
        Name => ''Description'',
        Searchable => 1,
        Input => {
            Type => ''TextArea'',
        },
    },
    {
        Key => ''Type'',
        Name => ''Type'',
        Searchable => 1,
        Input => {
            Type => ''GeneralCatalog'',
            Class => ''ITSM::ConfigItem::Computer::Type'',
            Translation => 1,
        },
    },
    {
        Key => ''Owner'',
        Name => ''Owner'',
        Searchable => 1,
        Input => {
            Type => ''Customer'',
        },
    },
    {
        Key => ''SerialNumber'',
        Name => ''Serial Number'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 100,
        },
    },
    {
        Key => ''OperatingSystem'',
        Name => ''Operating System'',
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 100,
        },
    },
    {
        Key => ''CPU'',
        Name => ''CPU'',
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 100,
        },
        CountMax => 16,
    },
    {
        Key => ''Ram'',
        Name => ''Ram'',
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 100,
        },
        CountMax => 10,
    },
    {
        Key => ''HardDisk'',
        Name => ''Hard Disk'',
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 100,
        },
        CountMax => 10,
        Sub => [
            {
                Key => ''Capacity'',
                Name => ''Capacity'',
                Input => {
                    Type => ''Text'',
                    Size => 20,
                    MaxLength => 10,
                },
            },
        ],
    },
    {
        Key => ''FQDN'',
        Name => ''FQDN'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 100,
        },
    },
    {
        Key => ''NIC'',
        Name => ''Network Adapter'',
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 100,
            Required => 1,
        },
        CountMin => 0,
        CountMax => 10,
        CountDefault => 1,
        Sub => [
            {
                Key => ''IPoverDHCP'',
                Name => ''IP over DHCP'',
                Input => {
                    Type => ''GeneralCatalog'',
                    Class => ''ITSM::ConfigItem::YesNo'',
                    Translation => 1,
                    Required => 1,
                },
            },
            {
                Key => ''IPAddress'',
                Name => ''IP Address'',
                Searchable => 1,
                Input => {
                    Type => ''Text'',
                    Size => 40,
                    MaxLength => 40,
                    Required => 1,
                },
                CountMin => 0,
                CountMax => 20,
                CountDefault => 0,
            },
        ],
    },
    {
        Key => ''GraphicAdapter'',
        Name => ''Graphic Adapter'',
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 100,
        },
    },
    {
        Key => ''OtherEquipment'',
        Name => ''Other Equipment'',
        Input => {
            Type => ''TextArea'',
            Required => 1,
        },
        CountMin => 0,
        CountDefault => 0,
    },
    {
        Key => ''WarrantyExpirationDate'',
        Name => ''Warranty Expiration Date'',
        Searchable => 1,
        Input => {
            Type => ''Date'',
            YearPeriodPast => 20,
            YearPeriodFuture => 10,
        },
    },
    {
        Key => ''InstallDate'',
        Name => ''Install Date'',
        Searchable => 1,
        Input => {
            Type => ''Date'',
            Required => 1,
            YearPeriodPast => 20,
            YearPeriodFuture => 10,
        },
        CountMin => 0,
        CountDefault => 0,
    },
    {
        Key => ''Note'',
        Name => ''Note'',
        Searchable => 1,
        Input => {
            Type => ''TextArea'',
            Required => 1,
        },
        CountMin => 0,
        CountDefault => 0,
    },
];', 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_definition
-- ----------------------------------------------------------
INSERT INTO configitem_definition (class_id, configitem_definition, version, create_time, create_by)
    VALUES
    (23, '[
    {
        Key => ''Vendor'',
        Name => ''Vendor'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 50,
        },
    },
    {
        Key => ''Model'',
        Name => ''Model'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 50,
        },
    },
    {
        Key => ''Description'',
        Name => ''Description'',
        Searchable => 1,
        Input => {
            Type => ''TextArea'',
        },
    },
    {
        Key => ''Type'',
        Name => ''Type'',
        Searchable => 1,
        Input => {
            Type => ''GeneralCatalog'',
            Class => ''ITSM::ConfigItem::Hardware::Type'',
            Translation => 1,
        },
    },
    {
        Key => ''Owner'',
        Name => ''Owner'',
        Searchable => 1,
        Input => {
            Type => ''Customer'',
        },
    },
    {
        Key => ''SerialNumber'',
        Name => ''Serial Number'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 100,
        },
    },
    {
        Key => ''WarrantyExpirationDate'',
        Name => ''Warranty Expiration Date'',
        Searchable => 1,
        Input => {
            Type => ''Date'',
            YearPeriodPast => 20,
            YearPeriodFuture => 10,
        },
    },
    {
        Key => ''InstallDate'',
        Name => ''Install Date'',
        Searchable => 1,
        Input => {
            Type => ''Date'',
            Required => 1,
            YearPeriodPast => 20,
            YearPeriodFuture => 10,
        },
        CountMin => 0,
        CountMax => 1,
        CountDefault => 0,
    },
    {
        Key => ''Note'',
        Name => ''Note'',
        Searchable => 1,
        Input => {
            Type => ''TextArea'',
            Required => 1,
        },
        CountMin => 0,
        CountMax => 1,
        CountDefault => 0,
    },
];', 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_definition
-- ----------------------------------------------------------
INSERT INTO configitem_definition (class_id, configitem_definition, version, create_time, create_by)
    VALUES
    (24, '[
    {
        Key => ''Type'',
        Name => ''Type'',
        Searchable => 1,
        Input => {
            Type => ''GeneralCatalog'',
            Class => ''ITSM::ConfigItem::Location::Type'',
            Translation => 1,
        },
    },
    {
        Key => ''Phone1'',
        Name => ''Phone 1'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 100,
        },
    },
    {
        Key => ''Phone2'',
        Name => ''Phone 2'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 100,
        },
    },
    {
        Key => ''Fax'',
        Name => ''Fax'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 100,
        },
    },
    {
        Key => ''E-Mail'',
        Name => ''E-Mail'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 100,
        },
    },
    {
        Key => ''Address'',
        Name => ''Address'',
        Searchable => 1,
        Input => {
            Type => ''TextArea'',
        },
    },
    {
        Key => ''Note'',
        Name => ''Note'',
        Searchable => 1,
        Input => {
            Type => ''TextArea'',
            Required => 1,
        },
        CountMin => 0,
        CountDefault => 0,
    },
];', 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_definition
-- ----------------------------------------------------------
INSERT INTO configitem_definition (class_id, configitem_definition, version, create_time, create_by)
    VALUES
    (25, '[
    {
        Key => ''Description'',
        Name => ''Description'',
        Searchable => 1,
        Input => {
            Type => ''TextArea'',
        },
    },
    {
        Key => ''Type'',
        Name => ''Type'',
        Searchable => 1,
        Input => {
            Type => ''GeneralCatalog'',
            Class => ''ITSM::ConfigItem::Network::Type'',
            Translation => 1,
        },
    },
    {
        Key => ''NetworkAddress'',
        Name => ''Network Address'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 30,
            MaxLength => 20,
            Required => 1,
        },
        CountMin => 0,
        CountMax => 100,
        CountDefault => 1,
        Sub => [
            {
                Key => ''SubnetMask'',
                Name => ''Subnet Mask'',
                Input => {
                    Type => ''Text'',
                    Size => 30,
                    MaxLength => 20,
                    ValueDefault => ''255.255.255.0'',
                    Required => 1,
                },
                CountMin => 0,
                CountMax => 1,
                CountDefault => 0,
            },
            {
                Key => ''Gateway'',
                Name => ''Gateway'',
                Input => {
                    Type => ''Text'',
                    Size => 30,
                    MaxLength => 20,
                    Required => 1,
                },
                CountMin => 0,
                CountMax => 10,
                CountDefault => 0,
            },
        ],
    },
    {
        Key => ''Note'',
        Name => ''Note'',
        Searchable => 1,
        Input => {
            Type => ''TextArea'',
            Required => 1,
        },
        CountMin => 0,
        CountMax => 1,
        CountDefault => 0,
    },
];', 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table configitem_definition
-- ----------------------------------------------------------
INSERT INTO configitem_definition (class_id, configitem_definition, version, create_time, create_by)
    VALUES
    (26, '[
    {
        Key => ''Vendor'',
        Name => ''Vendor'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 50,
        },
    },
    {
        Key => ''Version'',
        Name => ''Version'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 50,
        },
    },
    {
        Key => ''Description'',
        Name => ''Description'',
        Searchable => 1,
        Input => {
            Type => ''TextArea'',
        },
    },
    {
        Key => ''Type'',
        Name => ''Type'',
        Searchable => 1,
        Input => {
            Type => ''GeneralCatalog'',
            Class => ''ITSM::ConfigItem::Software::Type'',
            Translation => 1,
        },
    },
    {
        Key => ''Owner'',
        Name => ''Owner'',
        Searchable => 1,
        Input => {
            Type => ''Customer'',
        },
    },
    {
        Key => ''SerialNumber'',
        Name => ''Serial Number'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 50,
        },
    },
    {
        Key => ''LicenceType'',
        Name => ''Licence Type'',
        Searchable => 1,
        Input => {
            Type => ''GeneralCatalog'',
            Class => ''ITSM::ConfigItem::Software::LicenceType'',
            Translation => 1,
        },
    },
    {
        Key => ''LicenceKey'',
        Name => ''Licence Key'',
        Searchable => 1,
        Input => {
            Type => ''Text'',
            Size => 50,
            MaxLength => 50,
            Required => 1,
        },
        CountMin => 0,
        CountMax => 100,
        CountDefault => 0,
        Sub => [
            {
                Key => ''Quantity'',
                Name => ''Quantity'',
                Input => {
                    Type => ''Integer'',
                    ValueMin => 1,
                    ValueMax => 1000,
                    ValueDefault => 1,
                    Required => 1,
                },
                CountMin => 0,
                CountMax => 1,
                CountDefault => 0,
            },
            {
                Key => ''ExpirationDate'',
                Name => ''Expiration Date'',
                Input => {
                    Type => ''Date'',
                    Required => 1,
                    YearPeriodPast => 20,
                    YearPeriodFuture => 10,
                },
                CountMin => 0,
                CountMax => 1,
                CountDefault => 0,
            },
        ],
    },
    {
        Key => ''Media'',
        Name => ''Media'',
        Input => {
            Type => ''Text'',
            Size => 40,
            MaxLength => 20,
        },
    },
    {
        Key => ''Note'',
        Name => ''Note'',
        Searchable => 1,
        Input => {
            Type => ''TextArea'',
            Required => 1,
        },
        CountMin => 0,
        CountMax => 1,
        CountDefault => 0,
    },
];', 1, current_timestamp, 1);
-- ----------------------------------------------------------
--  insert into table imexport_template
-- ----------------------------------------------------------
INSERT INTO imexport_template (imexport_object, imexport_format, name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('User', 'CSV', 'User - ImportExport (auto-created map)', 1, 'Automatically created during UserImportExport installation', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table imexport_template
-- ----------------------------------------------------------
INSERT INTO imexport_template (imexport_object, imexport_format, name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('CustomerCompany', 'CSV', 'CustomerCompany (auto-created map)', 1, 'Automatically created during CustomerUserImportExport installation', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table imexport_template
-- ----------------------------------------------------------
INSERT INTO imexport_template (imexport_object, imexport_format, name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('CustomerUser', 'CSV', 'CustomerUser - Database Backend (auto-created map)', 1, 'Automatically created during CustomerUserImportExport installation', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table imexport_template
-- ----------------------------------------------------------
INSERT INTO imexport_template (imexport_object, imexport_format, name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('FAQ', 'CSV', 'FAQ (auto-created map)', 1, 'Automatically created during FAQImportExport installation', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table imexport_template
-- ----------------------------------------------------------
INSERT INTO imexport_template (imexport_object, imexport_format, name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Service2CustomerUser', 'CSV', 'Service2CustomerUser (auto-created map)', 1, 'Automatically created during ServiceImportExport installation', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table imexport_template
-- ----------------------------------------------------------
INSERT INTO imexport_template (imexport_object, imexport_format, name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('SLA', 'CSV', 'FAQ (auto-created map)', 1, 'Automatically created during ServiceImportExport installation', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table imexport_template
-- ----------------------------------------------------------
INSERT INTO imexport_template (imexport_object, imexport_format, name, valid_id, comments, create_by, create_time, change_by, change_time)
    VALUES
    ('Service', 'CSV', 'Service (auto-created map)', 1, 'Automatically created during ServiceImportExport installation', 1, current_timestamp, 1, current_timestamp);
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (2, 'DefaultValid', '1');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (3, 'CustomerBackend', 'CustomerUser');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (3, 'DefaultUserCustomerID', '');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (3, '', '');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (3, 'DefaultValid', '1');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (3, 'EnableMailDomainCustomerIDMapping', '');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (3, 'ForceImportInConfiguredCustomerBackend', '');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (3, 'ResetPassword', '');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (3, 'ResetPasswordSuffix', '');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (6, 'DefaultSLATypeID', '21');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (6, 'DefaultValid', '1');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (6, 'NumberOfAssignableServices', '50');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (7, 'DefaultCriticalityID', '3 normal');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (7, 'DefaultServiceTypeID', '14');
-- ----------------------------------------------------------
--  insert into table imexport_object
-- ----------------------------------------------------------
INSERT INTO imexport_object (template_id, data_key, data_value)
    VALUES
    (7, 'DefaultValid', '1');
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 0);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 1);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 2);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 3);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 4);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 5);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 6);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 7);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 8);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 9);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 10);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 11);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 12);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 13);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 14);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 15);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 16);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 17);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 18);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 19);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 20);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 21);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 22);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 23);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 24);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 25);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 26);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 27);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 28);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 29);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 30);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 31);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 32);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 33);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 34);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 35);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 36);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 37);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 38);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 39);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 40);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (1, 41);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (2, 0);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (2, 1);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (2, 2);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (2, 3);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (2, 4);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (2, 5);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (2, 6);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (2, 7);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (2, 8);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 0);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 1);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 2);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 3);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 4);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 5);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 6);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 7);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 8);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 9);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 10);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 11);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 12);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 13);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 14);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (3, 15);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (4, 0);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (4, 1);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (4, 2);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (4, 3);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (4, 4);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (4, 5);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (4, 6);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (4, 7);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (4, 8);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (4, 9);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (4, 10);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (4, 11);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (4, 12);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (5, 0);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (5, 1);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (5, 2);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (5, 3);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 0);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 1);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 2);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 3);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 4);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 5);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 6);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 7);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 8);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 9);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 10);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 11);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 12);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 13);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 14);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 15);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 16);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 17);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 18);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 19);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 20);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 21);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 22);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 23);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 24);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 25);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 26);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 27);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 28);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 29);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 30);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 31);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 32);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 33);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 34);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 35);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 36);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 37);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 38);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 39);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 40);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 41);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 42);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 43);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 44);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 45);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 46);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 47);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 48);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 49);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 50);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 51);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 52);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 53);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 54);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 55);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 56);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 57);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 58);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 59);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 60);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (6, 61);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (7, 0);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (7, 1);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (7, 2);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (7, 3);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (7, 4);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (7, 5);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (7, 6);
-- ----------------------------------------------------------
--  insert into table imexport_mapping
-- ----------------------------------------------------------
INSERT INTO imexport_mapping (template_id, position)
    VALUES
    (7, 7);
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (1, 'Key', 'UserTitle');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (1, 'Value', 'UserTitle');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (2, 'Key', 'UserLogin');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (2, 'Value', 'UserLogin');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (3, 'Key', 'UserFirstname');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (3, 'Value', 'UserFirstname');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (4, 'Key', 'UserLastname');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (4, 'Value', 'UserLastname');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (5, 'Key', 'UserEmail');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (5, 'Value', 'UserEmail');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (6, 'Key', 'UserPw');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (6, 'Value', 'UserPw');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (7, 'Key', 'Valid');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (7, 'Value', 'Validity');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (8, 'Key', 'UserTheme');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (8, 'Value', 'UserTheme');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (9, 'Key', 'UserLanguage');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (9, 'Value', 'UserLanguage');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (10, 'Key', 'UserComment');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (10, 'Value', 'UserComment');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (11, 'Key', 'UserSkin');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (11, 'Value', 'UserSkin');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (12, 'Key', 'OutOfOffice');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (12, 'Value', 'OutOfOffice');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (13, 'Key', 'OutOfOfficeStartYear');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (13, 'Value', 'OutOfOfficeStartYear');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (14, 'Key', 'OutOfOfficeStartMonth');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (14, 'Value', 'OutOfOfficeStartMonth');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (15, 'Key', 'OutOfOfficeStartDay');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (15, 'Value', 'OutOfOfficeStartDay');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (16, 'Key', 'OutOfOfficeEndYear');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (16, 'Value', 'OutOfOfficeEndYear');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (17, 'Key', 'OutOfOfficeEndMonth');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (17, 'Value', 'OutOfOfficeEndMonth');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (18, 'Key', 'OutOfOfficeEndDay');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (18, 'Value', 'OutOfOfficeEndDay');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (19, 'Key', 'UserSendMoveNotification');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (19, 'Value', 'UserSendMoveNotification');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (20, 'Key', 'UserSendFollowUpNotification');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (20, 'Value', 'UserSendFollowUpNotification');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (21, 'Key', 'UserSendNewTicketNotification');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (21, 'Value', 'UserSendNewTicketNotification');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (22, 'Key', 'UserSendLockTimeoutNotification');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (22, 'Value', 'UserSendLockTimeoutNotification');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (23, 'Key', 'CustomQueue000');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (23, 'Value', 'CustomQueue000');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (24, 'Key', 'CustomQueue001');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (24, 'Value', 'CustomQueue001');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (25, 'Key', 'CustomQueue002');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (25, 'Value', 'CustomQueue002');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (26, 'Key', 'CustomQueue003');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (26, 'Value', 'CustomQueue003');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (27, 'Key', 'CustomQueue004');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (27, 'Value', 'CustomQueue004');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (28, 'Key', 'CustomQueue005');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (28, 'Value', 'CustomQueue005');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (29, 'Key', 'CustomQueue006');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (29, 'Value', 'CustomQueue006');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (30, 'Key', 'CustomQueue007');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (30, 'Value', 'CustomQueue007');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (31, 'Key', 'CustomQueue008');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (31, 'Value', 'CustomQueue008');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (32, 'Key', 'CustomQueue009');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (32, 'Value', 'CustomQueue009');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (33, 'Key', 'Role000');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (33, 'Value', 'Role000');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (34, 'Key', 'Role001');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (34, 'Value', 'Role001');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (35, 'Key', 'Role002');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (35, 'Value', 'Role002');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (36, 'Key', 'Role003');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (36, 'Value', 'Role003');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (37, 'Key', 'Role004');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (37, 'Value', 'Role004');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (38, 'Key', 'Role005');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (38, 'Value', 'Role005');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (39, 'Key', 'Role006');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (39, 'Value', 'Role006');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (40, 'Key', 'Role007');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (40, 'Value', 'Role007');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (41, 'Key', 'Role008');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (41, 'Value', 'Role008');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (42, 'Key', 'Role009');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (42, 'Value', 'Role009');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (43, 'Key', 'CustomerID');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (43, 'Value', 'CustomerID');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (44, 'Key', 'CustomerCompanyName');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (44, 'Value', 'CustomerCompanyName');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (45, 'Key', 'CustomerCompanyStreet');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (45, 'Value', 'CustomerCompanyStreet');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (46, 'Key', 'CustomerCompanyZIP');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (46, 'Value', 'CustomerCompanyZIP');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (47, 'Key', 'CustomerCompanyCity');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (47, 'Value', 'CustomerCompanyCity');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (48, 'Key', 'CustomerCompanyCountry');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (48, 'Value', 'CustomerCompanyCountry');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (49, 'Key', 'CustomerCompanyURL');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (49, 'Value', 'CustomerCompanyURL');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (50, 'Key', 'CustomerCompanyComment');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (50, 'Value', 'CustomerCompanyComment');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (51, 'Key', 'Valid');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (51, 'Value', 'Validity');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (52, 'Key', 'UserTitle');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (52, 'Value', 'UserTitle');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (53, 'Key', 'UserFirstname');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (53, 'Value', 'UserFirstname');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (54, 'Key', 'UserLastname');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (54, 'Value', 'UserLastname');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (55, 'Key', 'UserLogin');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (55, 'Value', 'UserLogin');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (56, 'Key', 'UserPassword');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (56, 'Value', 'UserPassword');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (57, 'Key', 'UserEmail');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (57, 'Value', 'UserEmail');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (58, 'Key', 'UserCustomerID');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (58, 'Value', 'UserCustomerID');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (59, 'Key', 'UserPhone');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (59, 'Value', 'UserPhone');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (60, 'Key', 'UserFax');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (60, 'Value', 'UserFax');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (61, 'Key', 'UserMobile');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (61, 'Value', 'UserMobile');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (62, 'Key', 'UserStreet');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (62, 'Value', 'UserStreet');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (63, 'Key', 'UserZip');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (63, 'Value', 'UserZip');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (64, 'Key', 'UserCity');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (64, 'Value', 'UserCity');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (65, 'Key', 'UserCountry');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (65, 'Value', 'UserCountry');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (66, 'Key', 'UserComment');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (66, 'Value', 'UserComment');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (67, 'Key', 'Valid');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (67, 'Value', 'Validity');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (68, 'Identifier', '1');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (68, 'Key', 'Number');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (69, 'Key', 'Title');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (70, 'Key', 'Category');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (71, 'Key', 'State');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (72, 'Key', 'Language');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (73, 'Key', 'Approved');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (74, 'Key', 'Keywords');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (75, 'Key', 'Field1');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (76, 'Key', 'Field2');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (77, 'Key', 'Field3');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (78, 'Key', 'Field4');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (79, 'Key', 'Field5');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (80, 'Key', 'Field6');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (81, 'Identifier', '1');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (81, 'Key', 'CustomerUserLogin');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (82, 'Key', 'ServiceName');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (83, 'Key', 'ServiceID');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (84, 'Key', 'AssignmentActive');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (85, 'Identifier', '1');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (85, 'Key', 'Name');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (86, 'Key', 'Calendar');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (87, 'Key', 'Valid');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (88, 'Key', 'Comment');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (89, 'Key', 'FirstResponseTime');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (90, 'Key', 'FirstResponseNotify');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (91, 'Key', 'UpdateTime');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (92, 'Key', 'UpdateNotify');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (93, 'Key', 'SolutionTime');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (94, 'Key', 'SolutionNotify');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (95, 'Key', 'Type');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (96, 'Key', 'MinTimeBetweenIncidents');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (97, 'Key', 'AssignedService000');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (98, 'Key', 'AssignedService001');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (99, 'Key', 'AssignedService002');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (100, 'Key', 'AssignedService003');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (101, 'Key', 'AssignedService004');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (102, 'Key', 'AssignedService005');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (103, 'Key', 'AssignedService006');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (104, 'Key', 'AssignedService007');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (105, 'Key', 'AssignedService008');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (106, 'Key', 'AssignedService009');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (107, 'Key', 'AssignedService010');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (108, 'Key', 'AssignedService011');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (109, 'Key', 'AssignedService012');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (110, 'Key', 'AssignedService013');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (111, 'Key', 'AssignedService014');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (112, 'Key', 'AssignedService015');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (113, 'Key', 'AssignedService016');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (114, 'Key', 'AssignedService017');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (115, 'Key', 'AssignedService018');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (116, 'Key', 'AssignedService019');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (117, 'Key', 'AssignedService020');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (118, 'Key', 'AssignedService021');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (119, 'Key', 'AssignedService022');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (120, 'Key', 'AssignedService023');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (121, 'Key', 'AssignedService024');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (122, 'Key', 'AssignedService025');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (123, 'Key', 'AssignedService026');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (124, 'Key', 'AssignedService027');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (125, 'Key', 'AssignedService028');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (126, 'Key', 'AssignedService029');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (127, 'Key', 'AssignedService030');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (128, 'Key', 'AssignedService031');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (129, 'Key', 'AssignedService032');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (130, 'Key', 'AssignedService033');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (131, 'Key', 'AssignedService034');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (132, 'Key', 'AssignedService035');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (133, 'Key', 'AssignedService036');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (134, 'Key', 'AssignedService037');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (135, 'Key', 'AssignedService038');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (136, 'Key', 'AssignedService039');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (137, 'Key', 'AssignedService040');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (138, 'Key', 'AssignedService041');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (139, 'Key', 'AssignedService042');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (140, 'Key', 'AssignedService043');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (141, 'Key', 'AssignedService044');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (142, 'Key', 'AssignedService045');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (143, 'Key', 'AssignedService046');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (144, 'Key', 'AssignedService047');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (145, 'Key', 'AssignedService048');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (146, 'Key', 'AssignedService049');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (147, 'Identifier', '1');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (147, 'Key', 'ServiceID');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (148, 'Key', 'Name');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (149, 'Key', 'NameShort');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (150, 'Key', 'Valid');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (151, 'Key', 'Comment');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (152, 'Key', 'Type');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (153, 'Key', 'Criticality');
-- ----------------------------------------------------------
--  insert into table imexport_mapping_object
-- ----------------------------------------------------------
INSERT INTO imexport_mapping_object (mapping_id, data_key, data_value)
    VALUES
    (154, 'Key', 'CurInciState');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (1, 'Charset', 'UTF-8');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (1, 'ColumnSeparator', 'Semicolon');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (1, 'IncludeColumnHeaders', '1');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (2, 'Charset', 'UTF-8');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (2, 'ColumnSeparator', 'Semicolon');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (2, 'IncludeColumnHeaders', '1');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (3, 'Charset', 'UTF-8');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (3, 'ColumnSeparator', 'Semicolon');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (5, 'Charset', 'UTF-8');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (5, 'ColumnSeparator', 'Semicolon');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (6, 'Charset', 'UTF-8');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (6, 'ColumnSeparator', 'Semicolon');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (7, 'Charset', 'UTF-8');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (7, 'ColumnSeparator', 'Semicolon');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (4, 'Charset', 'UTF-8');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (4, 'ColumnSeparator', 'Semicolon');
-- ----------------------------------------------------------
--  insert into table imexport_format
-- ----------------------------------------------------------
INSERT INTO imexport_format (template_id, data_key, data_value)
    VALUES
    (4, 'IncludeColumnHeaders', '1');
SET standard_conforming_strings TO ON;
