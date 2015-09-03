%%====================================================================
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
%%====================================================================
-module(leo_tran_tests).
-author('Yosuke Hara').

-include("leo_tran.hrl").
-include_lib("eunit/include/eunit.hrl").


%%--------------------------------------------------------------------
%% TEST FUNCTIONS
%%--------------------------------------------------------------------
-ifdef(EUNIT).

%% To avoid unused warning
-export([wait_proc/4]).

all_delete_test_() ->
    {setup,
     fun ( ) ->
             application:start(leo_tran),
             ok
     end,
     fun (_) ->
             application:stop(leo_tran),
             ok
     end,
     [
      {"test compaction",
       {timeout, 10000, fun suite/0}},
      {"test wait/notify functionality",
       {timeout, 10000, fun wait_notify_simple/0}}
     ]}.

suite() ->
    ?debugFmt("### Start a transaction ###", []),
    Table = test,
    Key = <<"KEY">>,
    Method = get,
    Callback = leo_tran_handler_sample,
    ok = send_tran(72, Table, Key, Method, Callback),
    ?debugFmt("### Finished to send messages ###", []),

    timer:sleep(timer:seconds(10)),
    {ok, not_running} = leo_tran:state(Table, Key, Method),
    ok.

send_tran(0, Table, Key, Method, _Callback) ->
    timer:sleep(30),
    {ok, running} = leo_tran:state(Table, Key, Method),
    {ok,[{Table, Key, Method}]} = leo_tran:all_states(),
    ok;
send_tran(Index, Table, Key, Method, Callback) ->
    case Index rem 3 of
        0 ->
            spawn(fun() ->
                          {value, ok} = leo_tran:run(Table, Key, Method, Callback)
                  end);
        1 ->
            spawn(fun() ->
                          timeout = leo_tran:run(
                                      Table, Key, Method, Callback, [{?PROP_TIMEOUT, 100},
                                                                     {?PROP_IS_WAIT_FOR_TRAN, true}
                                                                    ])
                  end);
        2 ->
            spawn(fun() ->
                          {error, ?ERROR_ALREADY_HAS_TRAN} =
                              leo_tran:run(
                                Table, Key, Method, Callback, [{?PROP_TIMEOUT, timer:seconds(10)},
                                                               {?PROP_IS_WAIT_FOR_TRAN, false}
                                                              ])
                  end)
    end,
    send_tran(Index - 1, Table, Key, Method, Callback).

wait_proc(Parent, K, V, M) ->
    proc_lib:init_ack(Parent, ok),
    leo_tran_concurrent_container:wait(K, V, M).

wait_notify_simple() ->
    NumProc = 100,
    BeforeProcs = erlang:processes(),
    [proc_lib:start(?MODULE, wait_proc, [self(), key, val, method]) || _Seq <- lists:seq(1, NumProc)],
    MiddleProcs = erlang:processes(),
    [proc_lib:start(?MODULE, wait_proc, [self(), key, val, func]) || _Seq <- lists:seq(1, NumProc)],
    AfterProcs = erlang:processes(),
    NumBefore = length(BeforeProcs),
    NumAfter = length(AfterProcs),
    NumAfter = NumBefore + NumProc * 2,
    timer:sleep(3000),
    AfterProcs = erlang:processes(),
    leo_tran_concurrent_container:notify_all(key, val, null), % nop
    timer:sleep(1000),
    AfterProcs = erlang:processes(),
    leo_tran_concurrent_container:notify_all(key, val, func),
    timer:sleep(1000),
    MiddleProcs = erlang:processes(),
    leo_tran_concurrent_container:notify_all(key, val, method),
    timer:sleep(1000),
    BeforeProcs = erlang:processes(),
    ok.



-endif.
