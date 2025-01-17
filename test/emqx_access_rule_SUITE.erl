%%--------------------------------------------------------------------
%% Copyright (c) 2019-2023 EMQ Technologies Co., Ltd. All Rights Reserved.
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

-module(emqx_access_rule_SUITE).

-compile(export_all).
-compile(nowarn_export_all).

-include_lib("eunit/include/eunit.hrl").

all() -> emqx_ct:all(?MODULE).

init_per_suite(Config) ->
    emqx_ct_helpers:boot_modules([router, broker]),
    emqx_ct_helpers:start_apps([]),
    Config.

end_per_suite(_Config) ->
    emqx_ct_helpers:boot_modules(all),
    emqx_ct_helpers:stop_apps([]).

t_compile_clientid_common_name_alias_placeholders(_Config) ->
    Rule1 = {allow, all, pubsub, <<"%cida">>},
    ?assertEqual(
       {allow, all, pubsub, [{pattern,[<<"%cida">>]}]},
       emqx_access_rule:compile(Rule1)),

    Rule2 = {allow, all, pubsub, <<"%cna">>},
    ?assertEqual(
       {allow, all, pubsub, [{pattern,[<<"%cna">>]}]},
       emqx_access_rule:compile(Rule2)),

    ok.

t_match_clientid_common_name_alias_placeholders(_Config) ->
    ClientInfo1 = #{clientid => <<"something-123456789">>,
                    cn => <<"another-987654321">>,
                    clientid_alias => <<"123456789">>,
                    common_name_alias => <<"987654321">>
                   },

    Rule1 = {allow, all, pubsub, <<"t/%cida">>},
    Compiled1 = emqx_access_rule:compile(Rule1),
    ?assertEqual({matched, allow},
                 emqx_access_rule:match(
                   ClientInfo1,
                   <<"t/123456789">>,
                   Compiled1)),
    ?assertEqual(nomatch,
                 emqx_access_rule:match(
                   ClientInfo1,
                   <<"t/987654321">>,
                   Compiled1)),
    ?assertEqual(nomatch,
                 emqx_access_rule:match(
                   ClientInfo1,
                   <<"123456789">>,
                   Compiled1)),
    ?assertEqual(nomatch,
                 emqx_access_rule:match(
                   ClientInfo1,
                   <<"t/something-123456789">>,
                   Compiled1)),
    ?assertEqual(nomatch,
                 emqx_access_rule:match(
                   ClientInfo1,
                   <<"t/%cida">>,
                   Compiled1)),

    Rule2 = {allow, all, pubsub, <<"t/%cna">>},
    Compiled2 = emqx_access_rule:compile(Rule2),
    ?assertEqual(nomatch,
                 emqx_access_rule:match(
                   ClientInfo1,
                   <<"t/123456789">>,
                   Compiled2)),
    ?assertEqual({matched, allow},
                 emqx_access_rule:match(
                   ClientInfo1,
                   <<"t/987654321">>,
                   Compiled2)),
    ?assertEqual(nomatch,
                 emqx_access_rule:match(
                   ClientInfo1,
                   <<"987654321">>,
                   Compiled2)),
    ?assertEqual(nomatch,
                 emqx_access_rule:match(
                   ClientInfo1,
                   <<"t/another-987654321">>,
                   Compiled2)),
    ?assertEqual(nomatch,
                 emqx_access_rule:match(
                   ClientInfo1,
                   <<"t/%cida">>,
                   Compiled2)),

    ok.

t_compile(_) ->
    Rule1 = {allow, all, pubsub, <<"%u">>},
    Compile1 = {allow, all, pubsub, [{pattern,[<<"%u">>]}]},

    Rule2 = {allow, {ipaddr, "127.0.0.1"}, pubsub, <<"%c">>},
    Compile2 = {allow, {ipaddr, {{127,0,0,1}, {127,0,0,1}, 32}}, pubsub, [{pattern,[<<"%c">>]}]},

    Rule3 = {allow, {'and', [{client, <<"testClient">>}, {user, <<"testUser">>}]}, pubsub, [<<"testTopics1">>,  <<"testTopics2">>]},
    Compile3 = {allow, {'and', [{client, <<"testClient">>}, {user, <<"testUser">>}]}, pubsub, [[<<"testTopics1">>],  [<<"testTopics2">>]]},

    Rule4 = {allow, {'or', [{client, all}, {user, all}]}, pubsub, [ <<"testTopics1">>,  <<"testTopics2">>]},
    Compile4 = {allow, {'or', [{client, all}, {user, all}]}, pubsub, [[<<"testTopics1">>],  [<<"testTopics2">>]]},

    Rule5 = {allow, {ipaddrs, ["127.0.0.1", "192.168.1.0/24"]}, pubsub, <<"%c">>},
    Compile5 = {allow, {ipaddrs,[{{127,0,0,1},{127,0,0,1},32},
                                 {{192,168,1,0},{192,168,1,255},24}]},
                       pubsub,
                       [{pattern,[<<"%c">>]}]
               },

    ?assertEqual(Compile1, emqx_access_rule:compile(Rule1)),
    ?assertEqual(Compile2, emqx_access_rule:compile(Rule2)),
    ?assertEqual(Compile3, emqx_access_rule:compile(Rule3)),
    ?assertEqual(Compile4, emqx_access_rule:compile(Rule4)),
    ?assertEqual(Compile5, emqx_access_rule:compile(Rule5)).

t_unmatching_placeholders(_Config) ->
    EmptyClientInfo = #{ clientid => undefined
                       , username => undefined
                       },

    Topic1 = <<"%u">>,
    Rule1 = {allow, all, pubsub, <<"%u">>},
    Compiled1 = emqx_access_rule:compile(Rule1),
    ?assertEqual(
       nomatch,
       emqx_access_rule:match(EmptyClientInfo, Topic1, Compiled1)),
    Rule2 = {allow, all, pubsub, [{eq, <<"%u">>}]},
    Compiled2 = emqx_access_rule:compile(Rule2),
    ?assertEqual(
       {matched, allow},
       emqx_access_rule:match(EmptyClientInfo, Topic1, Compiled2)),

    Topic2 = <<"%c">>,
    Rule3 = {allow, all, pubsub, <<"%c">>},
    Compiled3 = emqx_access_rule:compile(Rule3),
    ?assertEqual(
       nomatch,
       emqx_access_rule:match(EmptyClientInfo, Topic2, Compiled3)),
    Rule4 = {allow, all, pubsub, [{eq, <<"%c">>}]},
    Compiled4 = emqx_access_rule:compile(Rule4),
    ?assertEqual(
       {matched, allow},
       emqx_access_rule:match(EmptyClientInfo, Topic2, Compiled4)),

    ok.

t_match(_) ->
    ClientInfo1 = #{zone => external,
                    clientid => <<"testClient">>,
                    username => <<"TestUser">>,
                    peerhost => {127,0,0,1}
                   },
    ClientInfo2 = #{zone => external,
                    clientid => <<"testClient">>,
                    username => <<"TestUser">>,
                    peerhost => {192,168,0,10}
                   },
    ClientInfo3 = #{zone => external,
                    clientid => <<"testClient">>,
                    username => <<"TestUser">>,
                    peerhost => undefined
                   },
    ?assertEqual({matched, deny}, emqx_access_rule:match([], [], {deny, all})),
    ?assertEqual({matched, allow}, emqx_access_rule:match([], [], {allow, all})),
    ?assertEqual(nomatch, emqx_access_rule:match(ClientInfo1, <<"Test/Topic">>,
                                                    emqx_access_rule:compile({allow, {user, all}, pubsub, []}))),
    ?assertEqual({matched, allow}, emqx_access_rule:match(ClientInfo1, <<"Test/Topic">>,
                                                            emqx_access_rule:compile({allow, {client, all}, pubsub, ["$SYS/#", "#"]}))),
    ?assertEqual(nomatch, emqx_access_rule:match(ClientInfo3, <<"Test/Topic">>,
                                                    emqx_access_rule:compile({allow, {ipaddr, "127.0.0.1"}, pubsub, ["$SYS/#", "#"]}))),
    ?assertEqual({matched, allow}, emqx_access_rule:match(ClientInfo1, <<"Test/Topic">>,
                                                            emqx_access_rule:compile({allow, {ipaddr, "127.0.0.1"}, subscribe, ["$SYS/#", "#"]}))),
    ?assertEqual({matched, allow}, emqx_access_rule:match(ClientInfo2, <<"Test/Topic">>,
                                                            emqx_access_rule:compile({allow, {ipaddr, "192.168.0.1/24"}, subscribe, ["$SYS/#", "#"]}))),
    ?assertEqual({matched, allow}, emqx_access_rule:match(ClientInfo1, <<"d/e/f/x">>,
                                                            emqx_access_rule:compile({allow, {user, "TestUser"}, subscribe, ["a/b/c", "d/e/f/#"]}))),
    ?assertEqual(nomatch, emqx_access_rule:match(ClientInfo1, <<"d/e/f/x">>,
                                                    emqx_access_rule:compile({allow, {user, "admin"}, pubsub, ["d/e/f/#"]}))),
    ?assertEqual({matched, allow}, emqx_access_rule:match(ClientInfo1, <<"testTopics/testClient">>,
                                                            emqx_access_rule:compile({allow, {client, "testClient"}, publish, ["testTopics/testClient"]}))),
    ?assertEqual({matched, allow}, emqx_access_rule:match(ClientInfo1, <<"clients/testClient">>,
                                                            emqx_access_rule:compile({allow, all, pubsub, ["clients/%c"]}))),
    ?assertEqual({matched, allow}, emqx_access_rule:match(#{username => <<"user2">>}, <<"users/user2/abc/def">>,
                                                            emqx_access_rule:compile({allow, all, subscribe, ["users/%u/#"]}))),
    ?assertEqual({matched, deny}, emqx_access_rule:match(ClientInfo1, <<"d/e/f">>,
                                                            emqx_access_rule:compile({deny, all, subscribe, ["$SYS/#", "#"]}))),
    ?assertEqual(nomatch, emqx_access_rule:match(ClientInfo1, <<"Topic">>,
                                                    emqx_access_rule:compile({allow, {'and', [{ipaddr, "127.0.0.1"}, {user, <<"WrongUser">>}]}, publish, <<"Topic">>}))),
    ?assertEqual({matched, allow}, emqx_access_rule:match(ClientInfo1, <<"Topic">>,
                                                            emqx_access_rule:compile({allow, {'and', [{ipaddr, "127.0.0.1"}, {user, <<"TestUser">>}]}, publish, <<"Topic">>}))),
    ?assertEqual({matched, allow}, emqx_access_rule:match(ClientInfo1, <<"Topic">>,
                                                            emqx_access_rule:compile({allow, {'or', [{ipaddr, "127.0.0.1"}, {user, <<"WrongUser">>}]}, publish, ["Topic"]}))),
    ?assertEqual({matched, allow}, emqx_access_rule:match(ClientInfo2, <<"Topic">>,
                                                          emqx_access_rule:compile({allow, {ipaddrs, ["127.0.0.1", "192.168.0.0/24"]}, publish, ["Topic"]}))).
