leo_tran
========

[![Build Status](https://secure.travis-ci.org/leo-project/leo_tran.png?branch=develop)](http://travis-ci.org/leo-project/leo_tran)

**leo_tran** is a library to handle a data-transaction.
We can easily write programs that manager a data-transaction to avoid a conflicts.

## Build Information

* "leo_tran" uses the [rebar](https://github.com/rebar/rebar) build system. Makefile so that simply running "make" at the top level should work.
* "leo_tran" requires Erlang R16B03-1 or later.


## Usage in Leo Project

**leo_tran** is used in [**leo_storage**](https://github.com/leo-project/leo_storage) and others.
It is used to reduce unnecessary request between remote-nodes.

## Usage

We prepare a server program and a client program to use **leo_tran**.

First, a callback program is as below:

```erlang
%% Launch leo_tran:
ok = application:start(leo_tran).
{value, {ok, Ret_1}} = leo_tran:run(<<"TABLE">>, <<"ID">>, leo_tran_handler_sample).

%% Able to control a transaction by options:
%%     - Default timeout: 5000 (ms)
%%     - Default is_wait_for_tran: true
%%     - Default is_lock_tran: true
{value, {ok, Ret_2}} = leo_tran:run(<<"TABLE">>, <<"ID">>, leo_tran_handler_sample,
                                   [{?PROP_TIMEOUT, timer:seconds(1)},
                                    {?PROP_IS_WAIT_FOR_TRAN, true},
                                    {?PROP_IS_LOCK_TRAN, true}
                                   ]).

%% A Callback Module:
-module(leo_tran_handler_sample).
-behaviour(leo_tran_behaviour).

-include("leo_tran.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([run/3, wait/3, resume/3,
         commit/3, rollback/4
       ]).

-define(MIN_DURATION, timer:seconds(1)).


%% @doc Launch a transaction
-spec(run(Table::atom(), Key::binary(), State::#tran_state{}) ->
             ok | {error, any()}).
run(Table, Key, State) ->
    ?debugFmt("=> RUN - START: ~w, ~p, ~w",
              [Table, Key, State#tran_state.started_at]),
    Duration = erlang:phash2(leo_date:clock(), timer:seconds(3)) + ?MIN_DURATION,
    timer:sleep(Duration),
    ?debugFmt("<= RUN - END: ~w, ~p, ~w",
              [Table, Key, State#tran_state.started_at]),
    ok.

%% @doc Waiting for a transaction,
%%      after finished the transaction, leo_tran executes resume-function
-spec(wait(Table::atom(), Key::binary(), State::#tran_state{}) ->
             ok | {error, any()}).
wait(Table, Key, State) ->
    ?debugFmt("* WAIT: ~w, ~p, ~w",
              [Table, Key, State#tran_state.started_at]),
    ok.

%% @doc Previous status is "waiting"
-spec(resume(Table::atom(), Key::binary(), State::#tran_state{}) ->
             ok | {error, any()}).
resume(Table, Key,_State) ->
    ?debugFmt("* RESUME: ~w, ~p", [Table, Key]),
    ok.


%% @doc If a transaction was successful, leo_tran calls commit-function
-spec(commit(Table::atom(), Key::binary(), State::#tran_state{}) ->
             ok | {error, any()}).
commit(Table, Key,_State) ->
    ?debugFmt("* COMMIT: ~w, ~p", [Table, Key]),
    ok.

%% @doc If a transaction failed, leo_tran calls rollback-function
-spec(rollback(Table::atom(), Key::binary(), Reason::any(), State::#tran_state{}) ->
             ok | {error, any()}).
rollback(Table, Key, Reason,_State) ->
    ?debugFmt("* ROLLBACK: ~w, ~p, ~p", [Table, Key, Reason]),
    ok.
```


## License

leo_tran's license is [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)