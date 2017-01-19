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
-module(leo_tran_behaviour).

-include("leo_tran.hrl").

-callback(run(Table::atom(), Key::any(), Method::atom(), UserContext::any(), State::#tran_state{}) ->
                 ok | {error, any()}).

-callback(wait(Table::atom(), Key::any(), Method::atom(), UserContext::any(), State::#tran_state{}) ->
                 ok | {error, any()}).

-callback(resume(Table::atom(), Key::any(), Method::atom(), UserContext::any(), State::#tran_state{}) ->
                 ok | {error, any()}).

-callback(commit(Table::atom(), Key::any(), Method::atom(), UserContext::any(), State::#tran_state{}) ->
                 ok | {error, any()}).

-callback(rollback(Table::atom(), Key::any(), Method::atom(), UserContext::any(), Reason::any(), State::#tran_state{}) ->
                 ok | {error, any()}).
