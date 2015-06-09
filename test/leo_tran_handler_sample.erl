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
-module(leo_tran_handler_sample).
-author('Yosuke Hara').

-behaviour(leo_tran_behaviour).

-include("leo_tran.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([run/3, wait/3, resume/3,
         commit/3, rollback/4
       ]).

-define(MIN_DURATION, timer:seconds(1)).

-spec(run(Table::atom(), Key::binary(), State::#tran_state{}) ->
             ok | {error, any()}).
run(Table, Key, State) ->
    ?debugFmt(">>> RUN - START: ~w, ~p, ~w",
              [Table, Key, State#tran_state.started_at]),
    Duration = erlang:phash2(leo_date:clock(), timer:seconds(3)) + ?MIN_DURATION,
    timer:sleep(Duration),
    ?debugFmt("<<< RUN - END: ~w, ~p, ~w",
              [Table, Key, State#tran_state.started_at]),
    ok.


-spec(wait(Table::atom(), Key::binary(), State::#tran_state{}) ->
             ok | {error, any()}).
wait(Table, Key, State) ->
    ?debugFmt("* WAIT: ~w, ~p, ~w",
              [Table, Key, State#tran_state.started_at]),
    ok.


-spec(resume(Table::atom(), Key::binary(), State::#tran_state{}) ->
             ok | {error, any()}).
resume(Table, Key,_State) ->
    ?debugFmt("=> RESUME: ~w, ~p", [Table, Key]),
    ok.


-spec(commit(Table::atom(), Key::binary(), State::#tran_state{}) ->
             ok | {error, any()}).
commit(Table, Key,_State) ->
    ?debugFmt("===> COMMIT: ~w, ~p", [Table, Key]),
    ok.


-spec(rollback(Table::atom(), Key::binary(), Reason::any(), State::#tran_state{}) ->
             ok | {error, any()}).
rollback(Table, Key, Reason,_State) ->
    ?debugFmt("===> ROLLBACK: ~w, ~p, ~p", [Table, Key, Reason]),
    ok.
