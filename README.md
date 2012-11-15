clicktochat_ejabberd
====================

Click To Chat implemented on Ejabberd

Before To Start
====

You must install Ejabberd and stop it!!

How To Start
====

Clone the project from github:

			$ git clone https://github.com/jorgegarrido/clicktochat_ejabberd.git

Move into project directory:

			$ cd clicktochat_ejabberd

Configure the file 'clicktochat.conf' correclty (each section in the file is described on it)

Let's compile and install:

			$ make && sudo make install

Enable Click To Chat
====

In the config file /etc/ejabberd/ejabberd.cfg configure the sections:

modules, add mod_clicktochat:

			{modules,
		         [...
          		  ...
          		  ...
          		  {mod_clicktochat, []}
         		 ]}.

and in the section ejabberd_http, add a new handler mod_http_clicktochat

			{5280, ejabberd_http, [...
                                   ...
                                   http_poll,
                                   %%register,
                                   web_admin,
                                   {request_handlers,
                                    [ {["clicktochat"], mod_http_clicktochat}]}
                                  ]}.


Registering client users
====

NOTE: At this step you must have created helpdesk users and they can be connected to ejabberd!

Let's create a single user, using http interface:

			$ curl -i -H "Accept: text/xml" -X POST -d "<?xml version='1.0'?><registration><username>my_client</username><password>123</password></registration>" http://IP:PORT/clicktochat/register

The response will be an xml containing the client's nick and the 
helpdesk user that is automatically linked to start the chat, from your
application you must send messages to this nick (helpdesk user).

Listing all users connected
====

Using http interface:

			curl -i -X GET http://IP:PORT/clicktochat/list

The response will be an xml containing all helpdesk users connected, now from your 
application you can choose one and start the chat.

Request - Response RESTful Services Description
====

	--------------------------------------------------------------------------------------------------------------------------------------
	|         URI             | Method |           Request Body             |              Response                 |  HTTP Status Codes |
	--------------------------------------------------------------------------------------------------------------------------------------
	|                         |        |   <?xml version='1.0'?>            |     <?xml version='1.0'?>             |                    |
	|  /clicktochat/register  |  POST  |   <registration>                   |     <register>                        |                    |
	|                         |        |     <username>username</username>  |       <status>ok</status>             |  201 (Created)     |            
	|                         |        |     <password>pass</password>      |       <from>user_from@domain</from>   |  400 (Bad Request) |
	|                         |        |   </registration>                  |       <to>user_to@domain</to>         |                    |
	|                         |        |                                    |     </register>                       |                    |
	--------------------------------------------------------------------------------------------------------------------------------------
	|                         |        |                                    |     <?xml version='1.0'?>             |                    |
	|  /clicktochat/list      |  GET   |              empty                 |     <connected_users>                 |  200 (Ok)          |
	|                         |        |                                    |       <username>username</username>   |  400 (Bad Request) |
	|                         |        |                                    |     </connected_users>                |                    |
	--------------------------------------------------------------------------------------------------------------------------------------
		

Round Robin Queue
====

This project implements the round robin in the queue, when a client user is registered
and connected, then in the queue, a helpdesk user is get and placed to the end
of the queue, ensuring that the client users are equally asigned to the helpdesk users,
avoiding that a single user attends all requests.

	queue                                                      then in the queue, get a user and pass to the end
	--------------                                             --------------
	|   USER-1   |                                             |   USER-2   |
	|------------|                                             |------------|
	|   USER-2   |  ======> a new client is registered ======> |   USER-3   |  =======>   now CLIENT-1 can start
	|------------|                   (CLIENT-1)                |------------|             a chat with USER-1
	|   USER-3   |                                             |   USER-1   |
	--------------                                             --------------

Integrating with Riak
====

To save the conversation into Riak database, you need configure clicktochat.conf file:

	{riak_erlang_client,Path} to set the riak erlang client path.
	{riak_cluster,cluster} to set your cluster info.


The structure for the conversation is:

         |                    |     [{record,[[{current_time, CurrentDate},               |
         |  IdHelpDeskuser    |                {user, User},                              | 
         |                    |                {conversation, Conversation}]]}]           |


Where in Conversation field has the next structure for each message:

                            |current_time^Currentime|from^From|to^T|msg^Msg|

General Message Format
====

The message has the next fields:

	current_time: current time that was sent the message
	from:	      person who send the message		
	to:	      person who receive the message		
	msg:          sent message  

Description about the format:

	* Field sequences in the message are separated by “|”.
	* Values from the fields are separated by “^”.


