%% -------------------------------------------------------------------
%% hooksI : hooks interface for clicktochat
%% Copyright (c) 2012 All Rights Reserved.
%% Jorge Garrido <jorge.garrido@morelosoft.com> [zgb]
%% -------------------------------------------------------------------

% module hooksI 
-module(hooksI).

% events ejabberd (hooks)
-export([on_user_available/1, on_sm_remove_connection/3,
	 on_user_send_packet/3]).

% include files
-include("ejabberd.hrl").
-include("clicktochat.hrl").

% types
-type jid() :: {jid, Username :: string(), Host :: string(), HostName :: string(),
                Username :: string(), Host :: string(), HostName :: string()}.

%% @doc When a user is available (came online), put in queue
%% @spec on_user_available(JID :: jid()) -> ok
-spec on_user_available(JID :: jid()) -> ok.
on_user_available(JID = {jid, _, Host, _, _, _, _}) ->
    ok = mod_clicktochat:user_online(Host, JID),
    ok.

%% @doc When a user is disconnected (came offline), remove from the queue
%% @spec on_sm_remove_connection(_SID :: tuple(), JID :: jid(), _SessionInfo :: any()) -> ok
-spec on_sm_remove_connection(_SID :: tuple(), JID :: jid(), _SessionInfo :: any()) -> ok.
on_sm_remove_connection(_SID, JID = {jid, Username, Host, _, _, _, _}, _SessionInfo) ->
    ok = mod_clicktochat:user_offline(Host, JID),
    ok = case config:host_client() of
	     Host ->
		 ok = ejabberd_auth:remove_user(Username, Host),
		 mod_clicktochat:remove_user(config:host_helpdesk(), Username ++ "@" ++ Host);
	     _    ->	ok
	 end, 
    ok.

%% @doc When a user sends a packet
%% @spec on_user_send_packet(From :: jid(), To :: jid(), Packet :: tuple()) -> ok
-spec on_user_send_packet(From :: jid(), To :: jid(), Packet :: tuple()) -> ok.
on_user_send_packet({jid,FromNick,FromHost,_,_,_,_}, {jid,ToNick,ToHost,_,_,_,_}, 
                    {xmlelement,"message",_,[_,{xmlelement, "body", _, [{xmlcdata, Data}|_]}|_]}) ->
    {ok, QueueBusy} = mod_clicktochat:get_queue_busy(config:host_helpdesk()),
    FromUser= FromNick++"@"++FromHost,
    ToUser= ToNick++"@"++ToHost,
    {Key, Client}= case FromHost =:= config:host_client() of
		       true  ->   
			   {jid,NameUser,HostUser,_,_,_,_} = proplists:get_value(FromUser,QueueBusy),
			   {NameUser++"@"++HostUser, FromUser};
		       false ->   
			   {jid,NameUser,HostUser,_,_,_,_} = proplists:get_value(ToUser,QueueBusy),
			   {NameUser++"@"++HostUser, ToUser}
		   end,
    rqc_s(Key, {FromUser, ToUser, Data, Client}),
    ok;

on_user_send_packet(_From, _To, _Packet) ->
    ok.

%% @doc Riak query for store (a process for store messages and whole conversation)
%% @spec rqc_s(Key ::string(), {From :: string(), To :: string(), Msg :: string(), Client :: string()}) -> ok
-spec rqc_s(Key ::string(), {From :: string(), To :: string(), Msg :: string(), Client :: string()}) -> ok.
rqc_s(Key, {From, To, Msg, Client}) ->
    [ true = code:add_path(Path) || Path <- config:riak_erlang_client() ],
    {ok, Pid} = active_node(config:riak_cluster()),
    {{YY, MM, DD}, {HH, MS, SS}} = DateTime = {date(), time()},
    case riakc_pb_socket:get(Pid, <<"clicktochat">>, list_to_binary(Key)) of
        {error, notfound} -> 
	    Obj = riakc_obj:new(<<"clicktochat">>, 
				list_to_binary(Key),
				term_to_binary(?clicktochat_struct(DateTime, Client, 
								   ?struct_message(YY,MM,DD,HH,
										   MS,SS,From,To,
										   binary_to_list(Msg))))),
            ok = riakc_pb_socket:put(Pid, Obj);
        {ok, Obj}          -> 
	    [{record,Records}] = binary_to_term(riakc_obj:get_value(Obj)),	  
	    NewVal = [begin 
			  case User=:=Client andalso DateMsg=:=date() of 
			      true ->
				  [{current_time, CD}, {user, User}, 
				   {conversation, Conversation ++ ?sm ++
				    ?struct_message(YY, MM, DD, HH, MS, SS,
						    From,To,binary_to_list(Msg))}];
			      false ->
				  Value
			  end
		      end|| Value = [{current_time, CD={DateMsg, _}},{user, User},
				     {conversation, Conversation}] <-Records],
	    ObjReplace = case Records =:= NewVal of
			     true ->
				 riakc_obj:update_value(Obj,term_to_binary([{record,Records ++ [[{current_time, DateTime},
												 {user, Client},
												 {conversation, ?struct_message(YY, MM, DD, HH, MS, SS,
																From,To,
																binary_to_list(Msg))}]]}]));			     
			     false ->
				 riakc_obj:update_value(Obj,term_to_binary([{record,NewVal}]))  
			 end,
            ok = riakc_pb_socket:put(Pid, ObjReplace)
    end.

%% @doc get active node connection to Riak 
%% @spec active_node( Cluster :: list()) -> {ok, Pid :: pid()} | ok.
-spec active_node( Cluster :: list()) -> {ok, Pid :: pid()} | ok.
active_node([])                      ->
    ?INFO_MSG("[WARNING] : no active nodes on Riak Cluster", []);
active_node([{Ip, Port} | Cluster ]) ->
    case riakc_pb_socket:start_link(Ip, Port) of
        {ok, Pid} ->  {ok, Pid};
        _         ->  active_node(Cluster)
    end.



