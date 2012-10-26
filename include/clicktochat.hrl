%% -------------------------------------------------------------------
%% clicktochat.hrl : include for clicktochat
%% Copyright (c) 2012 All Rights Reserved.
%% Jorge Garrido <jorge.garrido@morelosoft.com> [zgb]
%% -------------------------------------------------------------------

% get proc for a module (implementing behavior 'gen_mod')
-define(get_proc(Host, Module), gen_mod:get_module_proc(Host, Module)).

% content type in http request
-define(content_type(Ctype), [{"Content-Type", Ctype}]).

% config file path for clicktochat 
% MY CONFIGURATION GOES HERE!!
-define(config_file, "/etc/ejabberd/clicktochat.conf").

% message structure
-define(struct_message(Year, Month, Day, Hours, Minutes, Seconds, From, To, Msg),
"|current_time^"++ ?format_date(Year, Month, Day) ++" "++ ?format_time(Hours, Minutes, Seconds)++"|from^"++From++"|to^"++To++"|msg^"++Msg++"|"). 

% message separator
-define(sm,"&").

% macro to save info into Riak
-define(clicktochat_struct(CurrentDate, User, Conversation), [{record,[[{current_time, CurrentDate},
                                                                         {user, User},
                                                                         {conversation, Conversation}]]}]).
% convert erlang format time to string
-define(format_time(Hours, Minutes, Seconds),
lists:flatten(io_lib:fwrite("~2..0w:~2..0w:~2..0w", [Hours,Minutes,Seconds]))).

% convert erlang format date to string
-define(format_date(Year, Month, Day),
lists:flatten(io_lib:fwrite("~4..0w-~2..0w-~2..0w", [Year, Month, Day]))).





