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

-module(emqx_banned_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("emqx/include/emqx.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("snabbkaffe/include/snabbkaffe.hrl").

all() -> emqx_ct:all(?MODULE).

init_per_suite(Config) ->
    emqx_ct_helpers:start_apps([]),
    ok = ekka:start(),
    %% for coverage
    ok = emqx_banned:mnesia(copy),
    Config.

end_per_suite(_Config) ->
    ekka:stop(),
    ekka_mnesia:ensure_stopped(),
    ekka_mnesia:delete_schema(),
    emqx_ct_helpers:stop_apps([]).

t_add_delete(_) ->
    Banned = #banned{who = {clientid, <<"TestClient">>},
                     by = <<"banned suite">>,
                     reason = <<"test">>,
                     at = erlang:system_time(second),
                     until = erlang:system_time(second) + 1000
                    },
    ok = emqx_banned:create(Banned),
    ?assertEqual(1, emqx_banned:info(size)),

    ok = emqx_banned:delete({clientid, <<"TestClient">>}),
    ?assertEqual(0, emqx_banned:info(size)).

t_check(_) ->
    ok = emqx_banned:create(#banned{who = {clientid, <<"BannedClient">>}}),
    ok = emqx_banned:create(#banned{who = {username, <<"BannedUser">>}}),
    ok = emqx_banned:create(#banned{who = {peerhost, {192,168,0,1}}}),
    ?assertEqual(3, emqx_banned:info(size)),
    ClientInfo1 = #{clientid => <<"BannedClient">>,
                    username => <<"user">>,
                    peerhost => {127,0,0,1}
                   },
    ClientInfo2 = #{clientid => <<"client">>,
                    username => <<"BannedUser">>,
                    peerhost => {127,0,0,1}
                   },
    ClientInfo3 = #{clientid => <<"client">>,
                    username => <<"user">>,
                    peerhost => {192,168,0,1}
                   },
    ClientInfo4 = #{clientid => <<"client">>,
                    username => <<"user">>,
                    peerhost => {127,0,0,1}
                   },
    ?assert(emqx_banned:check(ClientInfo1)),
    ?assert(emqx_banned:check(ClientInfo2)),
    ?assert(emqx_banned:check(ClientInfo3)),
    ?assertNot(emqx_banned:check(ClientInfo4)),
    ok = emqx_banned:delete({clientid, <<"BannedClient">>}),
    ok = emqx_banned:delete({username, <<"BannedUser">>}),
    ok = emqx_banned:delete({peerhost, {192,168,0,1}}),
    ?assertNot(emqx_banned:check(ClientInfo1)),
    ?assertNot(emqx_banned:check(ClientInfo2)),
    ?assertNot(emqx_banned:check(ClientInfo3)),
    ?assertNot(emqx_banned:check(ClientInfo4)),
    ?assertEqual(0, emqx_banned:info(size)).

t_unused(_) ->
    Banned = case emqx_banned:start_link() of
                 {ok, Pid} -> Pid;
                 {error, {already_started, Pid}} -> Pid
             end,
    ok = emqx_banned:create(#banned{who = {clientid, <<"BannedClient">>},
                                    until = erlang:system_time(second)}),
    ?assertEqual(ignored, gen_server:call(Banned, unexpected_req)),
    ?assertEqual(ok, gen_server:cast(Banned, unexpected_msg)),
    ?assertEqual(ok, Banned ! ok),
    timer:sleep(500), %% expiry timer
    ok = emqx_banned:stop().

t_kick(_) ->
    ClientId = <<"client">>,
    snabbkaffe:start_trace(),

    Now = erlang:system_time(second),
    Who = {clientid, ClientId},

    emqx_banned:create(#{
        who => Who,
        by => <<"test">>,
        reason => <<"test">>,
        at => Now,
        until => Now + 120
    }),

    Trace = snabbkaffe:collect_trace(),
    snabbkaffe:stop(),
    emqx_banned:delete(Who),
    ?assertEqual(1, length(?of_kind(kick_session_due_to_banned, Trace))).
