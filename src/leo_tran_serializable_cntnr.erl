%%======================================================================
%%
%% Leo Transaction Manager
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
-module(leo_tran_serializable_cntnr).

-behaviour(gen_server).

-include("leo_tran.hrl").
-include_lib("eunit/include/eunit.hrl").

%% API
-export([start_link/0,
         stop/0]).

%% data operations.
-export([run/6, run/7,
         state/3,
         all_states/0
        ]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3
        ]).

-record(state, {monitor_list = [],
                tran_list = []
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
%% Data Operation related.
%%--------------------------------------------------------------------
%% @doc Run a transaction
%%
-spec(run(Table, Key, Method, Callback, UserContext, Options) ->
             ok | {error, any()} when Table::atom(),
                                      Key::any(),
                                      Method::atom(),
                                      Callback::module(),
                                      UserContext::any(),
                                      Options::[{tran_prop(), any()}]).
run(Table, Key, Method, Callback, UserContext, Options) ->
    run(Table, Key, Method, Callback, UserContext, Options, ?DEF_TIMEOUT).

-spec(run(Table, Key, Method, Callback, UserContext, Options, Timeout) ->
             ok | {error, any()} when Table::atom(),
                                      Key::any(),
                                      Method::atom(),
                                      Callback::module(),
                                      UserContext::any(),
                                      Options::[{tran_prop(), any()}],
                                      Timeout::non_neg_integer|infinity).
run(Table, Key, Method, Callback, UserContext, Options, Timeout) ->
    gen_server:call(?MODULE, {run, Table, Key, Method, Callback, UserContext, Options}, Timeout).


%% @doc Retrieve a state by the table and the key
%%
-spec(state(Table, Key, Method) ->
             {ok, running | not_running} |
             {error, any()} when Table::atom(),
                                 Key::any(),
                                 Method::atom()).
state(Table, Key, Method) ->
    gen_server:call(?MODULE, {state, Table, Key, Method}, ?DEF_TIMEOUT).


%% @doc Retrieve all states
%%
-spec(all_states() ->
             {ok, binary()} |
             not_found |
             {error, any()}).
all_states() ->
    gen_server:call(?MODULE, all_states, ?DEF_TIMEOUT).


%%--------------------------------------------------------------------
%% GEN_SERVER CALLBACKS
%%--------------------------------------------------------------------
%% @doc gen_server callback - Module:init(Args) -> Result
init([]) ->
    {ok, #state{monitor_list = dict:new(),
                tran_list = dict:new()}}.


%% @doc gen_server callback - Module:handle_call(Request, From, State) -> Result
handle_call(stop, _From, State) ->
    {stop, normal, stopped, State};


%%--------------------------------------------------------------------
%% Data Operation related.
%%--------------------------------------------------------------------
handle_call({run, Table, Key, Method, Callback, UserContext, Options},
            From, #state{monitor_list = MonitorList,
                         tran_list = TranList} = State) ->
    %%  Check already started transaction(s)
    %%  And need to lock the transaction
    HasTran = (error /= dict:find({Table, Key, Method}, TranList)),
    CanStartTran = case leo_misc:get_value(?PROP_IS_WAIT_FOR_TRAN, Options, true) of
                       true ->
                           true;
                       false when HasTran == false ->
                           true;
                       false ->
                           false
                   end,
    CanLockTran = leo_misc:get_value(?PROP_IS_LOCK_TRAN, Options, true),

    %%  Launch a transaction
    case CanStartTran of
        true ->
            case leo_tran_handler:start_link(self(), Table, Key,
                                             Method, Callback, UserContext, Options) of
                {ok, ChildPid} ->
                    MonitorRef = erlang:monitor(process, ChildPid),
                    Clock = leo_date:clock(),
                    Verb = case HasTran of
                               false ->
                                   run;
                               true when CanLockTran == false ->
                                   run;
                               true ->
                                   wait
                           end,
                    ok = erlang:apply(leo_tran_handler, Verb, [ChildPid, MonitorRef]),
                    TranList_1 = dict:append({Table, Key, Method},
                                             {MonitorRef, ChildPid, Clock}, TranList),
                    MonList_1 = dict:store(MonitorRef, {Table, Key, Method,
                                                        From, ChildPid, Clock}, MonitorList),
                    {noreply, State#state{monitor_list = MonList_1,
                                          tran_list = TranList_1}};
                {error, Cause} ->
                    {reply, {error, Cause}, State}
            end;
        false ->
            {reply, {error, ?ERROR_ALREADY_HAS_TRAN}, State}
    end;

handle_call({state, Table, Key, Method},_From, #state{tran_list = TranList} = State) ->
    Ret = case (error == dict:find({Table, Key, Method}, TranList)) of
              true ->
                  not_running;
              false ->
                  running
          end,
    {reply, {ok, Ret}, State};

handle_call(all_states,_From, #state{tran_list = TranList} = State) ->
    RetL = case (dict:size(TranList) == 0) of
               true ->
                   [];
               false ->
                   [{Tbl, Key, Method}
                    || {{Tbl, Key, Method},_} <- dict:to_list(TranList)]
           end,
    {reply, {ok, RetL}, State};

handle_call(_Msg,_,State) ->
    {reply, ok, State}.


%% @doc gen_server callback - Module:handle_cast(Request, State) -> Result
handle_cast(_Msg, State) ->
    {noreply, State}.


%% @doc gen_server callback - Module:handle_info(Info, State) -> Result
handle_info({Msg, ChildPid, MonitorRef, TranState, Table, Key, Method, Reply},
            #state{monitor_list = MonList,
                   tran_list = TranList} = State) when Msg == finished;
                                                       Msg == error;
                                                       Msg == timeout ->
    %% Modify the monitor-reference list
    MonitorRef_1 = get_monitor_ref(MonitorRef, ChildPid, MonList),
    MonList_1 = case dict:find(MonitorRef_1, MonList) of
                    {ok,{_Table,_Key,_Method, From,_ChildPid,_StartedAt}} ->
                        gen_server:reply(From, Reply),
                        dict:erase(MonitorRef, MonList);
                    _ ->
                        MonList
                end,

    %% Modify the transaction list
    TranList_1 = case dict:find({Table, Key, Method}, TranList) of
                     {ok, RetL} ->
                         MonRefL = exclude_monitor_ref(RetL, MonitorRef, []),
                         case TranState of
                             run ->
                                 _ = send_reume_to_waiting_procs(MonRefL, MonList),
                                 dict:erase({Table, Key, Method}, TranList);
                             _ ->
                                 TranList
                         end;
                     _ ->
                         TranList
                 end,
    {noreply, State#state{monitor_list = MonList_1,
                          tran_list = TranList_1}};
handle_info({'DOWN', MonitorRef, _Type,_Pid, _Info}, #state{monitor_list = MonList,
                                                            tran_list = TranList} = State) ->
    {Table_1, Key_1, Method_1, MonList_1} =
        case dict:find(MonitorRef, MonList) of
            {ok,{Table, Key, Method, From,_StartedAt}} ->
                gen_server:reply(From, {error, badtran}),
                {Table, Key, Method, dict:erase(MonitorRef, MonList)};
            _ ->
                {null, null, null, MonList}
        end,

    TranList_1 =
        case (Table_1 /= null andalso Key_1 /= null andalso Method_1 /= null) of
            true ->
                case dict:find({Table_1, Key_1, Method_1}, TranList) of
                    {ok, RetL} ->
                        MonRefL = exclude_monitor_ref(RetL, MonitorRef, []),
                        dict:store({Table_1, Key_1, Method_1}, MonRefL, TranList);
                    _ ->
                        TranList
                end;
            false ->
                TranList
        end,
    {noreply, State#state{monitor_list = MonList_1,
                          tran_list = TranList_1}};
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
%% @doc Exclude a monitor reference from the monitor list
%% @private
exclude_monitor_ref([],_MonitorRef, Acc) ->
    Acc;
exclude_monitor_ref([{MonitorRef,_,_}|Rest], MonitorRef, Acc) ->
    exclude_monitor_ref(Rest, MonitorRef, Acc);
exclude_monitor_ref([{_MonitorRef,_,_} = Info|Rest],_, Acc) ->
    exclude_monitor_ref(Rest,_MonitorRef, [Info|Acc]).


%% @doc Send a resume-message to waiting processes
%% @private
send_reume_to_waiting_procs([], MonList) ->
    {ok, MonList};
send_reume_to_waiting_procs([{MonitorRef,_,_}|Rest], MonList) ->
    MonList_1 = case dict:find(MonitorRef, MonList) of
                    {ok,{_Table,_Key,_Method,_From,ChildPid,_StartedAt}} ->
                        ok = leo_tran_handler:resume(ChildPid, MonitorRef),
                        dict:erase(MonitorRef, MonList);
                    _ ->
                        MonList
                end,
    send_reume_to_waiting_procs(Rest, MonList_1).


%% @doc Retrieve a monitor-list
%% @private
get_monitor_ref(null, ChildPid, MonitorList) ->
    lists:foldl(fun({MonitorRef, {_Table,_Key,_Method,_From,_ChildPid,_Clock}}, SoFar) ->
                        case _ChildPid of
                            ChildPid ->
                                MonitorRef;
                            _ ->
                                SoFar
                        end
                end, [], dict:to_list(MonitorList));
get_monitor_ref(MonitorRef,_,_) ->
    MonitorRef.
