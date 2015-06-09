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
-module(leo_tran).
-author('Yosuke Hara').

-include_lib("eunit/include/eunit.hrl").

%% Application callbacks
-export([run/3, run/4,
         state/2,
         all_states/0
        ]).

%% ===================================================================
%% API
%% ===================================================================
%% @doc Execute a taransaction
%%
-spec(run(Tbl, Key, Callback) ->
             ok | {error, any()} when Tbl::atom(),
                                      Key::any(),
                                      Callback::module()).
run(Tbl, Key, Callback) ->
    run(Tbl, Key, Callback, []).

-spec(run(Tbl, Key, Callback, Timeout) ->
             ok | {error, any()} when Tbl::atom(),
                                      Key::any(),
                                      Callback::module(),
                                      Timeout::pos_integer()).
run(Tbl, Key, Callback, Options) ->
    leo_tran_container:run(Tbl, Key, Callback, Options).


%% @doc Retrieve state of the transaction
%%
-spec(state(Tbl, Key) ->
             {ok, State} | {error, any()} when Tbl::atom(),
                                               Key::any(),
                                               State::running | not_running).
state(Tbl, Key) ->
    leo_tran_container:state(Tbl, Key).


%% @doc Retrieve all state of the transactions
%%
-spec(all_states() ->
             {ok, [{Table, Key, State}]} |
             {error, any()} when Table::atom(),
                                 Key::any(),
                                 State::running | not_running).
all_states() ->
    leo_tran_container:all_states().
