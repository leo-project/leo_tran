leo_tran
========

**leo_tran** is a library to handle data transactions.
You can easily write programs that manage data transactions to avoid conflicts.

## Build Information

* **leo_tran** uses [rebar3](https://www.rebar3.org/) as the build system.
* Requires Erlang/OTP 22 or later (tested with OTP 28).

## Quick Start

```bash
# Compile
make compile

# Run tests
make eunit

# Run xref analysis
make xref

# Clean build artifacts
make clean
```

## Usage in Leo Project

**leo_tran** is used in [**leo_storage**](https://github.com/leo-project/leo_storage) and other Leo Project components.
It is used to reduce unnecessary requests between remote nodes.

## Usage

### Basic Usage

```erlang
%% Start the application (leo_commons must be started first)
ok = application:ensure_started(leo_commons),
ok = application:start(leo_tran).

%% Run a transaction
Table = my_table,
Key = <<"my_key">>,
Method = get,
Callback = my_tran_handler,
UserContext = #{user_data => some_value},

{value, ok} = leo_tran:run(Table, Key, Method, Callback, UserContext).
```

### Transaction Options

You can control transaction behavior with options:

```erlang
Options = [
    {timeout, timer:seconds(10)},      %% Transaction timeout (default: 5000ms)
    {is_wait_for_tran, true},          %% Wait for existing transaction (default: true)
    {is_lock_tran, true}               %% Lock the transaction (default: true)
],

{value, ok} = leo_tran:run(Table, Key, Method, Callback, UserContext, Options).
```

### Checking Transaction State

```erlang
%% Check if a transaction is running
{ok, running} = leo_tran:state(Table, Key, Method).
{ok, not_running} = leo_tran:state(Table, Key, Method).

%% Get all active transactions
{ok, [{Table, Key, Method}, ...]} = leo_tran:all_states().
```

### Wait/Notify Pattern

```erlang
%% Block the caller until notify_all is called
spawn(fun() -> leo_tran:wait(Table, Key, Method) end).

%% Resume all waiting processes
leo_tran:notify_all(Table, Key, Method).
```

## Callback Module

Implement the `leo_tran_behaviour` to create a transaction handler:

```erlang
-module(my_tran_handler).
-behaviour(leo_tran_behaviour).

-include_lib("leo_tran/include/leo_tran.hrl").

-export([run/5, wait/5, resume/5, commit/5, rollback/6]).

%% Called when the transaction starts
-spec run(Table, Key, Method, UserContext, State) -> ok | {error, any()} when
    Table :: atom(),
    Key :: any(),
    Method :: atom(),
    UserContext :: any(),
    State :: #tran_state{}.
run(Table, Key, Method, UserContext, State) ->
    %% Your transaction logic here
    io:format("Running transaction: ~p/~p/~p~n", [Table, Key, Method]),
    ok.

%% Called when waiting for another transaction
-spec wait(Table, Key, Method, UserContext, State) -> ok | {error, any()} when
    Table :: atom(),
    Key :: any(),
    Method :: atom(),
    UserContext :: any(),
    State :: #tran_state{}.
wait(_Table, _Key, _Method, _UserContext, _State) ->
    ok.

%% Called when resuming after waiting
-spec resume(Table, Key, Method, UserContext, State) -> ok | {error, any()} when
    Table :: atom(),
    Key :: any(),
    Method :: atom(),
    UserContext :: any(),
    State :: #tran_state{}.
resume(Table, Key, Method, UserContext, State) ->
    %% Continue transaction after waiting
    run(Table, Key, Method, UserContext, State).

%% Called on successful completion
-spec commit(Table, Key, Method, UserContext, State) -> ok | {error, any()} when
    Table :: atom(),
    Key :: any(),
    Method :: atom(),
    UserContext :: any(),
    State :: #tran_state{}.
commit(_Table, _Key, _Method, _UserContext, _State) ->
    ok.

%% Called on failure
-spec rollback(Table, Key, Method, UserContext, Reason, State) -> ok | {error, any()} when
    Table :: atom(),
    Key :: any(),
    Method :: atom(),
    UserContext :: any(),
    Reason :: any(),
    State :: #tran_state{}.
rollback(_Table, _Key, _Method, _UserContext, _Reason, _State) ->
    ok.
```

## Transaction State Record

The `#tran_state{}` record contains:

```erlang
-record(tran_state, {
    table :: atom(),
    key :: any(),
    method :: atom(),
    is_lock_tran :: boolean(),
    is_wait_for_tran :: boolean(),
    state :: tran_state(),
    timeout :: pos_integer(),
    started_at :: integer()
}).
```

## Dependencies

* [leo_commons](https://github.com/leo-project/leo_commons) >= 1.3.0

## License

leo_tran's license is [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)
