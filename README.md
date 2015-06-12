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
Method = get,
{value, {ok, Ret_1}} = leo_tran:run(<<"TABLE">>, <<"ID">>, Method, leo_tran_handler_sample).

%% Able to control a transaction by options:
%%     - Default timeout: 5000 (ms)
%%     - Default is_wait_for_tran: true
%%     - Default is_lock_tran: true
{value, {ok, Ret_2}} = leo_tran:run(<<"TABLE">>, <<"ID">>, Method, leo_tran_handler_sample,
                                   [{?PROP_TIMEOUT, timer:seconds(1)},
                                    {?PROP_IS_WAIT_FOR_TRAN, true},
                                    {?PROP_IS_LOCK_TRAN, true}
                                   ]).

%% A Callback Module:
-module(leo_tran_handler_sample).
-behaviour(leo_tran_behaviour).
-include("leo_tran.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([run/4, wait/4, resume/4,
         commit/4, rollback/5]).

-define(MIN_DURATION, timer:seconds(1)).

-spec(run(Table::atom(), Key::binary(), Method::atom(), State::#tran_state{}) ->
             ok | {error, any()}).
run(Table, Key, get, State) ->
    ?debugFmt("GET: ~w, ~p, ~w",
              [Table, Key, State#tran_state.started_at]),
    ok;
run(Table, Key, put, State) ->
    ?debugFmt("PUT: ~w, ~p, ~w",
              [Table, Key, State#tran_state.started_at]),
    ok;
run(Table, Key, delete, State) ->
    ?debugFmt("DELETE: ~w, ~p, ~w",
              [Table, Key, State#tran_state.started_at]),
    ok;
run(_,_,_,_) ->
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


-spec(rollback(Table::atom(), Key::binary(), Method::atom(),
               Reason::any(), State::#tran_state{}) ->
             ok | {error, any()}).
rollback(Table, Key, Method, Reason,_State) ->
    ?debugFmt("===> ROLLBACK: ~w, ~p, ~w, ~p", [Table, Key, Method, Reason]),
    ok.
```


## License

leo_tran's license is [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)