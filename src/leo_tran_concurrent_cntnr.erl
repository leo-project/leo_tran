%%======================================================================
%%
%% Leo Transaction Concurrent Container
%%
%% Copyright (c) 2012-2015 Rakuten, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%%======================================================================
-module(leo_tran_concurrent_cntnr).

-behaviour(gen_server).

-include("leo_tran.hrl").
-include_lib("eunit/include/eunit.hrl").

%% API for start/stop container
-export([start_link/0,
         stop/0]).

%% API for Synchronization
-export([wait/3,
         notify_all/3
        ]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3
        ]).

-record(state,
        {
          wait_list = []
        }).

-define(DEF_TIMEOUT, 30000).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
%% @doc Creates the gen_server process as part of a supervision tree
-spec(start_link() ->
             {ok,pid()} | ignore | {error, any()}).
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Close the process
stop() ->
    gen_server:call(?MODULE, stop, ?DEF_TIMEOUT).


%%--------------------------------------------------------------------
%% API for Synchronization
%%--------------------------------------------------------------------
%% @doc Block the caller process until notify_all/3 is called from another process
%%
-spec(wait(Table, Key, Method) ->
             ok when Table::atom(),
                     Key::any(),
                     Method::atom()).
wait(Table, Key, Method) ->
    gen_server:call(?MODULE, {wait, Table, Key, Method}, ?DEF_TIMEOUT).


%% @doc Resume all blocked processes invoking wait/3
%%
-spec(notify_all(Table, Key, Method) ->
             ok when Table::atom(),
                     Key::any(),
                     Method::atom()).
notify_all(Table, Key, Method) ->
    gen_server:call(?MODULE, {notify_all, Table, Key, Method}, ?DEF_TIMEOUT).


%%--------------------------------------------------------------------
%% GEN_SERVER CALLBACKS
%%--------------------------------------------------------------------
%% @doc gen_server callback - Module:init(Args) -> Result
init([]) ->
    {ok, #state{wait_list = dict:new()}}.


%% @doc gen_server callback - Module:handle_call(Request, From, State) -> Result
handle_call(stop, _From, State) ->
    {stop, normal, stopped, State};


%%--------------------------------------------------------------------
%% Data Operation related.
%%--------------------------------------------------------------------
handle_call({wait, Table, Key, Method},
            From, #state{wait_list = WaitList} = State) ->
    %% Add a caller process to wait list
    NewWaitList = dict:append({Table, Key, Method}, From, WaitList),
    {noreply, State#state{wait_list = NewWaitList}};

handle_call({notify_all, Table, Key, Method},
            _From, #state{wait_list = WaitList} = State) ->
    case dict:find({Table, Key, Method}, WaitList) of
        {ok, PidList} ->
            [gen_server:reply(WaitProc, ok) || WaitProc <- PidList],
            {reply, ok, State#state{wait_list = dict:erase({Table, Key, Method}, WaitList)}};
        error ->
            {reply, ok, State}
    end;

handle_call(_Msg,_,State) ->
    {reply, ok, State}.


%% @doc gen_server callback - Module:handle_cast(Request, State) -> Result
handle_cast(_Msg, State) ->
    {noreply, State}.


%% @doc gen_server callback - Module:handle_info(Info, State) -> Result
handle_info(_Info, State) ->
    {noreply, State}.


%% @doc This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%% <p>
%% gen_server callback - Module:terminate(Reason, State)
%% </p>
terminate(_Reason,_State) ->
    ok.


%% @doc Convert process state when code is changed
%% <p>
%% gen_server callback - Module:code_change(OldVsn, State, Extra) -> {ok, NewState} | {error, Reason}.
%% </p>
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%%--------------------------------------------------------------------
%% INNER FUNCTIONS
%%--------------------------------------------------------------------
