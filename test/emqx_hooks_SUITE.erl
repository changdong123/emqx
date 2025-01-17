%%--------------------------------------------------------------------
%% Copyright (c) 2018-2023 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_hooks_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("eunit/include/eunit.hrl").

all() -> emqx_ct:all(?MODULE).

init_per_testcase(_Test, Config) ->
    Config.

end_per_testcase(_Test, _Config) ->
    _ = (catch emqx_hooks:stop()),
    _ = clear_orders().

t_add_del_hook(_) ->
    {ok, _} = emqx_hooks:start_link(),
    ok = emqx:hook(test_hook, fun ?MODULE:hook_fun1/1, []),
    ok = emqx:hook(test_hook, fun ?MODULE:hook_fun2/1, []),
    ?assertEqual({error, already_exists},
                 emqx:hook(test_hook, fun ?MODULE:hook_fun2/1, [])),
    Callbacks = [{callback, {fun ?MODULE:hook_fun1/1, []}, undefined, 0},
                 {callback, {fun ?MODULE:hook_fun2/1, []}, undefined, 0}],
    ?assertEqual(Callbacks, emqx_hooks:lookup(test_hook)),
    ok = emqx:unhook(test_hook, fun ?MODULE:hook_fun1/1),
    ok = emqx:unhook(test_hook, fun ?MODULE:hook_fun2/1),
    timer:sleep(200),
    ?assertEqual([], emqx_hooks:lookup(test_hook)),

    ok = emqx:hook(emqx_hook, {?MODULE, hook_fun8, []}, 8),
    ok = emqx:hook(emqx_hook, {?MODULE, hook_fun2, []}, 2),
    ok = emqx:hook(emqx_hook, {?MODULE, hook_fun10, []}, 10),
    ok = emqx:hook(emqx_hook, {?MODULE, hook_fun9, []}, 9),
    Callbacks2 = [{callback, {?MODULE, hook_fun10, []}, undefined, 10},
                  {callback, {?MODULE, hook_fun9, []}, undefined, 9},
                  {callback, {?MODULE, hook_fun8, []}, undefined, 8},
                  {callback, {?MODULE, hook_fun2, []}, undefined, 2}],
    ?assertEqual(Callbacks2, emqx_hooks:lookup(emqx_hook)),
    ok = emqx:unhook(emqx_hook, {?MODULE, hook_fun2, []}),
    ok = emqx:unhook(emqx_hook, {?MODULE, hook_fun8, []}),
    ok = emqx:unhook(emqx_hook, {?MODULE, hook_fun9, []}),
    ok = emqx:unhook(emqx_hook, {?MODULE, hook_fun10, []}),
    timer:sleep(200),
    ?assertEqual([], emqx_hooks:lookup(emqx_hook)),
    ok = emqx_hooks:stop().

t_run_hooks(_) ->
    {ok, _} = emqx_hooks:start_link(),
    ok = emqx:hook(foldl_hook, fun ?MODULE:hook_fun3/4, [init]),
    ok = emqx:hook(foldl_hook, {?MODULE, hook_fun3, [init]}),
    ok = emqx:hook(foldl_hook, fun ?MODULE:hook_fun4/4, [init]),
    ok = emqx:hook(foldl_hook, fun ?MODULE:hook_fun5/4, [init]),
    [r5,r4] = emqx:run_fold_hook(foldl_hook, [arg1, arg2], []),
    [] = emqx:run_fold_hook(unknown_hook, [], []),

    ok = emqx:hook(foldl_hook2, fun ?MODULE:hook_fun9/2),
    ok = emqx:hook(foldl_hook2, {?MODULE, hook_fun10, []}),
    [r9] = emqx:run_fold_hook(foldl_hook2, [arg], []),

    ok = emqx:hook(foreach_hook, fun ?MODULE:hook_fun6/2, [initArg]),
    {error, already_exists} = emqx:hook(foreach_hook, fun ?MODULE:hook_fun6/2, [initArg]),
    ok = emqx:hook(foreach_hook, fun ?MODULE:hook_fun7/2, [initArg]),
    ok = emqx:hook(foreach_hook, fun ?MODULE:hook_fun8/2, [initArg]),
    ok = emqx:run_hook(foreach_hook, [arg]),

    ok = emqx:hook(foreach_filter1_hook, {?MODULE, hook_fun1, []}, {?MODULE, hook_filter1, []}, 0),
    ?assertEqual(ok, emqx:run_hook(foreach_filter1_hook, [arg])), %% filter passed
    ?assertEqual(ok, emqx:run_hook(foreach_filter1_hook, [arg1])), %% filter failed

    ok = emqx:hook(foldl_filter2_hook, {?MODULE, hook_fun2, []}, {?MODULE, hook_filter2, [init_arg]}),
    ok = emqx:hook(foldl_filter2_hook, {?MODULE, hook_fun2_1, []}, {?MODULE, hook_filter2_1, [init_arg]}),
    ?assertEqual(3, emqx:run_fold_hook(foldl_filter2_hook, [arg], 1)),
    ?assertEqual(2, emqx:run_fold_hook(foldl_filter2_hook, [arg1], 1)),

    ok = emqx_hooks:stop().

t_uncovered_func(_) ->
    {ok, _} = emqx_hooks:start_link(),
    Pid = erlang:whereis(emqx_hooks),
    gen_server:call(Pid, test),
    gen_server:cast(Pid, test),
    Pid ! test,
    ok = emqx_hooks:stop().

t_explicit_order_acl(_) ->
    HookPoint = 'client.check_acl',
    test_explicit_order(acl_order, HookPoint).

t_explicit_order_auth(_) ->
    HookPoint = 'client.authenticate',
    test_explicit_order(auth_order, HookPoint).

test_explicit_order(ConfigKey, HookPoint) ->
    {ok, _} = emqx_hooks:start_link(),

    ok = set_orders(ConfigKey, "mod_a, mod_b"),

    ok = emqx:hook(HookPoint, {mod_c, cb, []}, 5),
    ok = emqx:hook(HookPoint, {mod_d, cb, []}, 0),
    ok = emqx:hook(HookPoint, {mod_b, cb, []}, 0),
    ok = emqx:hook(HookPoint, {mod_a, cb, []}, -1),
    ok = emqx:hook(HookPoint, {mod_e, cb, []}, -1),

    ?assertEqual(
       [
        {mod_a, cb, []},
        {mod_b, cb, []},
        {mod_c, cb, []},
        {mod_d, cb, []},
        {mod_e, cb, []}
       ],
       get_hookpoint_callbacks(HookPoint)).

t_reorder_callbacks_acl(_) ->
    F = fun emqx_hooks:reorder_acl_callbacks/0,
    ok = emqx_hooks:reorder_auth_callbacks(),
    test_reorder_callbacks(acl_order, 'client.check_acl', F).

t_reorder_callbacks_auth(_) ->
    F = fun emqx_hooks:reorder_auth_callbacks/0,
    test_reorder_callbacks(auth_order, 'client.authenticate', F).

test_reorder_callbacks(ConfigKey, HookPoint, ReorderFun) ->
    {ok, _} = emqx_hooks:start_link(),
    ok = set_orders(ConfigKey, "mod_a,mod_b,mod_c"),
    ok = emqx:hook(HookPoint, fun mod_c:foo/1),
    ok = emqx:hook(HookPoint, fun mod_a:foo/1),
    ok = emqx:hook(HookPoint, fun mod_b:foo/1),
    ok = emqx:hook(HookPoint, fun mod_y:foo/1),
    ok = emqx:hook(HookPoint, fun mod_x:foo/1),
    ?assertEqual(
       [fun mod_a:foo/1, fun mod_b:foo/1, fun mod_c:foo/1,
        fun mod_y:foo/1, fun mod_x:foo/1
       ],
       get_hookpoint_callbacks(HookPoint)),
    ok = set_orders(ConfigKey, "mod_x,mod_a,mod_c,mod_b"),
    ReorderFun(),
    ignored = gen_server:call(emqx_hooks, x),
    ?assertEqual(
       [fun mod_x:foo/1, fun mod_a:foo/1, fun mod_c:foo/1,
        fun mod_b:foo/1, fun mod_y:foo/1
       ],
       get_hookpoint_callbacks(HookPoint)),
    ok.

%%--------------------------------------------------------------------
%% Helpers
%%--------------------------------------------------------------------

set_orders(Key, OrderString) ->
    application:set_env(emqx, Key, OrderString).

clear_orders() ->
    application:set_env(emqx, acl_order, "none").

get_hookpoint_callbacks(HookPoint) ->
    [emqx_hooks:callback_action(C) || C <- emqx_hooks:lookup(HookPoint)].

%%--------------------------------------------------------------------
%% Hook fun
%%--------------------------------------------------------------------

hook_fun1(arg) -> ok;
hook_fun1(_) -> error.

hook_fun2(arg) -> ok;
hook_fun2(_) -> error.

hook_fun2(_, Acc) -> {ok, Acc + 1}.
hook_fun2_1(_, Acc) -> {ok, Acc + 1}.

hook_fun3(arg1, arg2, _Acc, init) -> ok.
hook_fun4(arg1, arg2, Acc, init)  -> {ok, [r4 | Acc]}.
hook_fun5(arg1, arg2, Acc, init)  -> {ok, [r5 | Acc]}.

hook_fun6(arg, initArg) -> ok.
hook_fun7(arg, initArg) -> ok.
hook_fun8(arg, initArg) -> ok.

hook_fun9(arg, Acc)  -> {stop, [r9 | Acc]}.
hook_fun10(arg, Acc) -> {stop, [r10 | Acc]}.

hook_filter1(arg) -> true;
hook_filter1(_) -> false.

hook_filter2(arg, _Acc, init_arg) -> true;
hook_filter2(_, _Acc, _IntArg) -> false.

hook_filter2_1(arg, _Acc, init_arg)  -> true;
hook_filter2_1(arg1, _Acc, init_arg) -> true;
hook_filter2_1(_, _Acc, _IntArg)     -> false.
