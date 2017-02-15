%%%-------------------------------------------------------------------
%%% @author Stefan Hagdahl
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 15. Feb 2017 16:05
%%%-------------------------------------------------------------------
-module(unrar).
-author("Stefan Hagdahl").

%% API
-export([extract/3,
         list/1]).


%%--------------------------------------------------------------------
%% @doc
%% Use 'unrar' to extract files to destination
%%
%% @end
%%--------------------------------------------------------------------
-spec(extract(RarFile :: string(), Files :: [string()],
              Destination :: string()) -> ok | {error, Reason :: term()}).
extract(RarFile, Files, Destination) ->
    Args = {args, ["e","-o+"] ++ [RarFile] ++ Files ++ [Destination]},
    Options = [exit_status, {line, 255}, Args],
    case os:find_executable("unrar") of
        false ->
            {error, "unrar not found in environment"};
        Unrar ->
            Port = erlang:open_port({spawn_executable, Unrar}, Options),
            case loop_messages(Port, []) of
                {ok, _Files} ->
                    ok;
                {error, Reason, _Files} ->
                    {error, Reason}
            end
    end.

%%--------------------------------------------------------------------
%% @doc
%% List files in compress rar file
%%
%% @end
%%--------------------------------------------------------------------
-spec(list(RarFile :: string()) -> [string()] | [] | {error, Reason :: term()}).
list(RarFile) ->
    Args = {args, ["lb", RarFile]},
    Options = [exit_status, {line, 255}, Args],
    case os:find_executable("unrar") of
        false ->
            {error, "unrar not found in environment"};
        Unrar ->
            Port = erlang:open_port({spawn_executable, Unrar}, Options),
            case loop_messages(Port, []) of
                {ok, Files} ->
                    Files;
                {error, Reason, _Files} ->
                    {error, Reason}
            end
    end.

%%--------------------------------------------------------------------
%% @doc
%% Loop and receive port message until closed or timed out and return
%% accumulated data
%%
%% @end
%%--------------------------------------------------------------------

-spec(loop_messages(Port :: port(), AccData :: list()) ->
    {ok, AccData :: list()} | {error, Reason :: term(), AccData :: list()}).
loop_messages(Port, AccData)
    when is_port(Port), is_list(AccData)->
    receive
        {Port, {data, {eol, Data}}} ->
            loop_messages(Port, AccData ++ [Data]);
        {Port, {data, {noeol, Data}}} ->
            loop_messages(Port, AccData ++ [Data]);
        {Port, {exit_status, ExitCode}} ->
            case ExitCode of
                0 ->
                    {ok, AccData};
                ExitCode ->
                    {error, "Unrar exited with exitcode:" ++
                            integer_to_list(ExitCode), AccData}
            end
    after
        10000 ->
            erlang:port_close(Port),
            {error, "Port timed out", AccData}
    end.