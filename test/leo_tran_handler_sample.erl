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

-export([run/4, wait/4, resume/4,
         commit/4, rollback/5
       ]).

-define(MIN_DURATION, timer:seconds(1)).

-spec(run(Table::atom(), Key::binary(), Method::atom(), State::#tran_state{}) ->
             ok | {error, any()}).
run(Table, Key, get = Method, State) ->
    ?debugFmt(">>> RUN - START: ~w, ~p, ~w, ~w",
              [Table, Key, Method, State#tran_state.started_at]),
    Duration = erlang:phash2(leo_date:clock(), timer:seconds(3)) + ?MIN_DURATION,
    timer:sleep(Duration),
    ?debugFmt("<<< RUN - END: ~w, ~p, ~w, ~w",
              [Table, Key, Method, State#tran_state.started_at]),
    ok;
run(_Table,_Key,_Method,_State) ->
    ok.


-spec(wait(Table::atom(), Key::binary(), Method::atom(), State::#tran_state{}) ->
             ok | {error, any()}).
wait(Table, Key, Method, State) ->
    ?debugFmt("* WAIT: ~w, ~p, ~w, ~w",
              [Table, Key, Method, State#tran_state.started_at]),
    ok.


-spec(resume(Table::atom(), Key::binary(), Method::atom(), State::#tran_state{}) ->
             ok | {error, any()}).
resume(Table, Key, Method,_State) ->
    ?debugFmt("=> RESUME: ~w, ~p, ~w", [Table, Key, Method]),
    ok.


-spec(commit(Table::atom(), Key::binary(), Method::atom(), State::#tran_state{}) ->
             ok | {error, any()}).
commit(Table, Key, Method,_State) ->
    ?debugFmt("===> COMMIT: ~w, ~p, ~w", [Table, Key, Method]),
    ok.


-spec(rollback(Table::atom(), Key::binary(), Method::atom(), Reason::any(), State::#tran_state{}) ->
             ok | {error, any()}).
rollback(Table, Key, Method, Reason,_State) ->
    ?debugFmt("===> ROLLBACK: ~w, ~p, ~w, ~p", [Table, Key, Method, Reason]),
    ok.
