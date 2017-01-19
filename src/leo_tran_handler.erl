%%======================================================================
%%
%% Leo Transaction Manager
%%
%% Copyright (c) 2012-2017 Rakuten, Inc.
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
-module(leo_tran_handler).

-behaviour(gen_server).

-include("leo_tran.hrl").
-include_lib("eunit/include/eunit.hrl").

%% API
-export([start_link/6,
         start_link/7,
         stop/1]).

%% data operations.
-export([run/2,
         wait/2,
         resume/2
        ]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3
        ]).

-record(state, {container :: pid(),
                monitor_ref :: reference(),
                table :: atom(),
                key = <<>> :: binary(),
                method :: atom(),
                callback :: module(),
                user_context :: any(),
                timeout = 0 :: non_neg_integer(),
                started_at = -1 :: integer()
               }).

-define(DEF_TIMEOUT, 30000).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
%% @doc Creates the gen_server process as part of a supervision tree
-spec(start_link(Container, Table, Key, Method, Callback, UserContext) ->
             {ok,pid()} | ignore | {error, any()} when Container::pid(),
                                                       Table::atom(),
                                                       Key::binary(),
                                                       Method::atom(),
                                                       UserContext::any(),
                                                       Callback::module()).
start_link(Container, Table, Key, Method, Callback, UserContext) ->
    start_link(Container, Table, Key, Method, Callback, UserContext, [{timeout, ?DEF_TIMEOUT}]).

-spec(start_link(Container, Table, Key, Method, Callback, UserContext, Options) ->
             {ok,pid()} | ignore | {error, any()} when Container::pid(),
                                                       Table::atom(),
                                                       Key::binary(),
                                                       Method::atom(),
                                                       Callback::module(),
                                                       UserContext::any(),
                                                       Options::[{tran_prop(), any()}]).
start_link(Container, Table, Key, Method, Callback, UserContext, Options) ->
    gen_server:start_link(?MODULE, [Container, Table, Key, Method, Callback, UserContext, Options], []).

%% @doc Stop this server
-spec(stop(PId) ->
             ok when PId::pid()).
stop(PId) ->
    gen_server:call(PId, stop, ?DEF_TIMEOUT).


%%--------------------------------------------------------------------
%% Data Operation related.
%%--------------------------------------------------------------------
%% @doc
%%
-spec(run(PId, MonitorRef) ->
             ok | {error, any()} when PId::pid(),
                                      MonitorRef::reference()).
run(PId, MonitorRef) ->
    gen_server:cast(PId, {run, MonitorRef}).

-spec(wait(PId, MonitorRef) ->
             ok | {error, any()} when PId::pid(),
                                      MonitorRef::reference()).
wait(PId, MonitorRef) ->
    gen_server:cast(PId, {wait, MonitorRef}).

-spec(resume(PId, MonitorRef) ->
             ok | {error, any()} when PId::pid(),
                                      MonitorRef::reference()).
resume(PId, MonitorRef) ->
    gen_server:cast(PId, {resume, MonitorRef}).


%%--------------------------------------------------------------------
%% GEN_SERVER CALLBACKS
%%--------------------------------------------------------------------
%% @doc gen_server callback - Module:init(Args) -> Result
init([Container, Table, Key, Method, Callback, UserContext, Options]) ->
    Timeout = leo_misc:get_value('timeout', Options, ?DEF_TIMEOUT),
    {ok, #state{container = Container,
                table = Table,
                key = Key,
                method = Method,
                callback = Callback,
                user_context = UserContext,
                started_at = leo_date:clock(),
                timeout = Timeout}, Timeout}.


%% @doc gen_server callback - Module:handle_call(Request, From, State) -> Result
handle_call(stop, _From, State) ->
    {stop, normal, ok, State};


%%--------------------------------------------------------------------
%% Data Operation related.
%%--------------------------------------------------------------------
handle_call(_Msg, _From, #state{timeout = Timeout} = State) ->
    {reply, ok, State, Timeout}.


%% @doc gen_server callback - Module:handle_cast(Request, State) -> Result
handle_cast({Msg, MonitorRef}, #state{container = Container,
                                      table = Table,
                                      key = Key,
                                      method = Method,
                                      callback = Callback,
                                      user_context = UserContext,
                                      timeout = Timeout} = State) when Msg == run orelse
                                                                       Msg == resume ->
    Reply = case catch erlang:apply(Callback, Msg,
                                    [Table, Key, Method, UserContext, state_to_tran_state(State)]) of
                {'EXIT', Cause} ->
                    ok = erlang:apply(Callback, rollback,
                                      [Table, Key, Method, UserContext, Cause, state_to_tran_state(State)]),
                    {badtran, Cause};
                Ret ->
                    case (Ret == ok orelse
                          erlang:element(1, Ret) == ok) of
                        true ->
                            ok = erlang:apply(Callback, commit, [Table, Key, Method, UserContext, State]);
                        false ->
                            ok = erlang:apply(Callback, rollback, [Table, Key, Method, UserContext, Ret, State])
                    end,
                    {value, Ret}
            end,
    erlang:send(Container, {finished, self(), MonitorRef,
                            Msg, Table, Key, Method, Reply}),
    _ = timer:apply_after(0, ?MODULE, stop, [self()]),
    {noreply, State, Timeout};

handle_cast({wait,_MonitorRef}, #state{container = Container,
                                       table = Table,
                                       key = Key,
                                       method = Method,
                                       callback = Callback,
                                       user_context = UserContext,
                                       timeout = Timeout} = State) ->
    Reply = case catch erlang:apply(Callback, wait,
                                    [Table, Key, Method, UserContext, state_to_tran_state(State)]) of
                {'EXIT', Cause} ->
                    {error, Cause};
                Ret ->
                    case (Ret == ok orelse
                          erlang:element(1, Ret) == ok) of
                        true ->
                            ok;
                        false ->
                            Ret
                    end
            end,
    case Reply of
        ok ->
            void;
        _ ->
            erlang:send(Container, {error, self(), null, null,
                                    Table, Key, Method, {error, wait_failure}}),
            _ = timer:apply_after(0, ?MODULE, stop, [self()])
    end,
    {noreply, State, Timeout};

handle_cast(_Msg, #state{timeout = Timeout} = State) ->
    {noreply, State, Timeout}.

%% @doc gen_server callback - Module:handle_info(Info, State) -> Result
handle_info('timeout', #state{container = Container,
                              table = Table,
                              key = Key,
                              method = Method,
                              timeout = Timeout} = State) ->
    erlang:send(Container, {timeout, self(), null, null, Table, Key, Method, timeout}),
    _ = timer:apply_after(0, ?MODULE, stop, [self()]),
    {noreply, State, Timeout};
handle_info(_Info, #state{timeout = Timeout} = State) ->
    {noreply, State, Timeout}.

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
state_to_tran_state(#state{table = Table,
                           key = Key,
                           method = Method,
                           started_at = StartedAt,
                           timeout = Timeout}) ->
    #tran_state{table = Table,
                key =  Key,
                method = Method,
                %% is_need_to_lock_tran     = false,
                %% is_need_to_wait_for_tran = false,
                started_at = StartedAt,
                timeout = Timeout}.
