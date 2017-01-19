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

-define(TIMEOUT, timer:seconds(5)).
-define(TRAN_RUNNING,    'running').
-define(TRAN_WAITING,    'waiting').
-define(TRAN_COMMITTED,  'committed').
-define(TRAN_ROLLBACKED, 'rollbacked').

-type(tran_state() :: ?TRAN_RUNNING |
                      ?TRAN_WAITING |
                      ?TRAN_COMMITTED |
                      ?TRAN_ROLLBACKED).

-define(PROP_TIMEOUT, 'timeout').
-define(PROP_IS_WAIT_FOR_TRAN, 'is_wait_for_tran').
-define(PROP_IS_LOCK_TRAN, 'is_lock_tran').
-type(tran_prop() :: ?PROP_TIMEOUT |
                     ?PROP_IS_WAIT_FOR_TRAN |
                     ?PROP_IS_LOCK_TRAN).

-record(tran_state, {
          table :: atom(),
          key = <<>> :: any(),
          method :: atom(),
          is_lock_tran     = false :: boolean(),
          is_wait_for_tran = false :: boolean(),
          state :: tran_state(),
          timeout = timer:seconds(5) :: pos_integer(),
          started_at = -1 :: integer()
         }).

-define(ERROR_ALREADY_HAS_TRAN, "Already has the transaction").
