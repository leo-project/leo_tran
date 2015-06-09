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
%% ---------------------------------------------------------------------
%% @doc leo_trans's app
%% @reference https://github.com/leo-project/leo_tran/blob/master/src/leo_tran_sup.erl
%% @end
%%======================================================================
-module(leo_tran_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SHUTDOWN_WAITING_TIME, 2000).
-define(MAX_RESTART, 5).
-define(MAX_TIME, 10).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    ChildSpec = {leo_tran_container,
                 {leo_tran_container, start_link, []},
                 permanent,
                 ?SHUTDOWN_WAITING_TIME,
                 worker,
                 [leo_tran_container]},
    {ok, { {one_for_one, ?MAX_RESTART, ?MAX_TIME}, [ChildSpec]} }.

