-module(server).
-export([create_account/2,close_account/2,login/2,logout/2,online/0,handle/4,invoke/1,score/1,loop/2,
  parseList/2,readAccounts/0,parse/1,parseUser/1,writeAccounts/1,start/1,server/1,acceptor/1,client/1,
  handleClientInput/2,leaderboard/0, member/2,nivel/1, game/1,initGame/3,clientGame/3,clientGameLoop/4,
  gameTimer/2,gameLoop/2,parseGame/2,parsePowerup/1,gerapowerup/0,handleInput/2, powerupCollisionsAux/2,
  powerupCollisions/2,distancia/4,geranovojogador/7
]).

% FILES ------------------------------------------------------------------------------------------------------------------------------------

parseList([], Users) -> Users;
parseList([H|T], Users) ->
  [User, UserInfo] = string:split(H, "."),
  [Password, UserInfo2] = string:split(UserInfo, "."),
  [Level, UserInfo3] = string:split(UserInfo2, "."),
  [Score, NPartidas] = string:split(UserInfo3, "."),
  NewUsers = maps:put(binary_to_list(User), {binary_to_list(Password),false,binary_to_integer(Level), binary_to_integer(Score),binary_to_integer(NPartidas)}, Users),
  if
    T == [] -> NewUsers;
    true -> parseList(string:split(T, "\r\n"), NewUsers)
  end.


readAccounts() ->
  ResFile = file:read_file("users.txt"),
  case ResFile of
    {error, _Reason} ->
      {ok, NewFile} = file:open("users.txt", [write]),
      file:close(NewFile),
      #{};
    {ok, File} ->
      FileList = string:split(File, "\r\n"),
      case FileList of
        [<<>>] -> #{};
        _FileList ->parseList(FileList, #{})
      end
  end.


parseUser({User, {Password,_,Nivel,Score,NPartidas}}) ->
  string:join([User, Password, integer_to_list(Nivel),integer_to_list(Score),integer_to_list(NPartidas)], ".").


parse(L) ->
  case L of
    [] -> "";
    [H] -> parseUser(H);
    [H | T] -> string:join([parseUser(H), parse(T)], "\r\n")
  end.


writeAccounts(Users) -> file:write_file("users.txt", parse(maps:to_list(Users))).


% SERVER CONNECTION ------------------------------------------------------------------------------------------------------------------------------------


start(Port) -> register(?MODULE,spawn(fun() -> server(Port) end)).


server(Port) ->
  {ok, LSock} = gen_tcp:listen(Port, [ {packet, line}, {reuseaddr, true}]),
  spawn(fun() -> acceptor(LSock) end),
  Party = spawn(fun() -> party([]) end),
  loop(readAccounts(),Party),
  receive stop -> ok end.


acceptor(LSock) ->
  ResTCP = gen_tcp:accept(LSock),
  spawn(fun() -> acceptor(LSock) end),
  case ResTCP of
    {error, Reason} -> io:fwrite("Error - Can't connect to tcp.\n"), Reason;
    {ok, Sock} -> client(Sock)
  end.


client(Sock) ->
  receive
    {line, Data} ->
      gen_tcp:send(Sock, Data),
      client(Sock);
    {tcp, _, Data} ->
      handleClientInput(string:trim(Data), Sock),
      client(Sock);
    {tcp_closed, _} ->
      {leave, self()};
    {tcp_error, _, _} ->
      {leave, self()}
  end.


% MENU ------------------------------------------------------------------------------------------------------------------------------------


invoke(Request)->
  ?MODULE ! {Request,self()},
  receive {Res,?MODULE}-> Res end.


create_account(User,Pass) -> invoke({create_account,User,Pass}).
close_account(User,Pass) -> invoke({close_account,User,Pass}).
login(User,Pass) -> invoke({login,User,Pass}).
logout(User,Pass) -> invoke({logout,User,Pass}).
score(User) -> invoke({score,User}).
nivel(User) -> invoke({nivel,User}).
online() -> invoke(online).
leaderboard()->invoke(leaderboard).


loop(Map,Party)->
  receive {Request,From} ->
    case Request of
      _->
        {Res,NextState,NewParty} = handle(Request,Map,Party,From),
        From ! {Res,?MODULE}
    end,
    loop(NextState,NewParty)
  end.


handle({create_account,User,Pass},Map,Party,From)->
  case maps:find(User,Map) of
    error->
      From ! done,
      {done, Map#{User =>{Pass,false,1,0,0}},Party};
    _ ->
      From ! user_exists,
      {user_exists,Map,Party}
  end;


handle({close_account,User,Pass},Map,Party,From)->
  case maps:find(User,Map) of
    {ok,{Pass,_,_,_,_}}->
      From ! done,
      {ok,maps:remove(User,Map),Party};
    _ ->
      From ! invalid,
      {invalid,Map,Party}
  end;


handle({login,User,Pass},Map,Party,From)->
  case maps:find(User,Map) of
    {ok,{Pass,_,Level,Score,NPartidas}}->
      From ! done,
      {ok,Map#{User =>{Pass,true,Level,Score,NPartidas}},Party};
    _->
      From ! invalid,
      {invalid,Map,Party}
  end;


handle({logout,User,Pass},Map,Party,From)->
  case maps:find(User,Map) of
    {ok,{Pass,true,Level,Score,NPartidas}}->
      From ! done,
      {ok,Map#{User =>{Pass,false,Level,Score,NPartidas}},Party};
    _->
      From ! invalid,
      {invalid,Map,Party}
  end;


handle({score,User},Map,Party,From)->
  case maps:find(User,Map) of
    {ok,{_,_,_,Score,_}}->
      From ! done,
      {Score,Map,Party};
    _->
      From ! invalid,
      {invalid,Map,Party}
  end;


handle({nivel,User},Map,Party,From)->
  case maps:find(User,Map) of
    {ok,{_,_,Level,_,_}}->
      From ! done,
      {Level,Map,Party};
    _->
      From ! invalid,
      {invalid,Map,Party}
  end;


handle(leaderboard,Map,Party,From)->
  UserList = [{User,Score} || {User, {_,_,_,Score,_}} <- maps:to_list(Map)],
  From ! UserList,
  {UserList,Map,Party};


handle(online,Map,Party,From) ->
  Res = [User || {User, {_,true,_,_,_}} <- maps:to_list(Map)],
  From ! Res, % tentar usar fold
  {Res,Map,Party};


handle({update,User,Level,Score,NPartidas},Map,Party,From)->
  case maps:find(User,Map) of
    {ok,{Pass,Estado,_,_,_}}->
      From! done,
      writeAccounts(Map#{User =>{Pass,Estado,list_to_integer(Level),list_to_integer(Score),list_to_integer(NPartidas)}}),
      {ok,Map#{User =>{Pass,Estado,list_to_integer(Level),list_to_integer(Score),list_to_integer(NPartidas)}},Party};
    _->
      From ! invalid,
      {invalid,Map,Party}
  end;


handle({join,User,Pass},Map,Party,From)->
  case maps:find(User, Map) of
    {ok, {Pass, true, Level,Score,NPartidas}} ->
      Party! {join,User,Level,Score,NPartidas,From},
      {done,Map,Party};
    _ ->
      From ! auth_fail,
      {auth_fail,Map,Party}
  end.


handleClientInput(String, Sock) ->
  case string:split(String, "#") of
    ["create_account", Info] ->
      io:fwrite(String),
      [User, Pass] = string:split(Info, " "),
      create_account(User,Pass),
      receive
        done-> gen_tcp:send(Sock, "Account created.\n");
        user_exists->gen_tcp:send(Sock, "User already exists.\n")
      end;
    ["close_account", Info] ->
      io:fwrite(String),
      [User, Pass] = string:split(Info, " "),
      close_account(User,Pass),
      receive
        done -> gen_tcp:send(Sock, "Account removed.\n");
        invalid -> gen_tcp:send(Sock, "Couldn't create account.\n")
      end;
    ["logout", Info] ->
      io:fwrite(String),
      [User, Pass] = string:split(Info, " "),
      logout(User,Pass),
      receive
        done -> gen_tcp:send(Sock, "Logged out.\n");
        invalid -> gen_tcp:send(Sock, "Couldn't leave account.\n")
      end;
    ["login", Info] ->
      io:fwrite(String),
      [User, Pass] = string:split(Info, " "),
      login(User,Pass),
      receive
        done -> gen_tcp:send(Sock, "Logged In.\n");
        invalid -> gen_tcp:send(Sock, "Incorrect username or password.\n")
      end;
    ["online", _] ->
      online(),
      receive
        Map ->
          Res = string:join(Map, " "),
          gen_tcp:send(Sock, string:join([Res, "\n"], ""))
      end;
    ["leaderboard",_] ->
      io:fwrite(String),
      invoke(leaderboard),
      receive
        Map ->
          AuxList = [{Username, Score} || {Username, Score} <- Map],
          Listaux = lists:reverse(lists:keysort(2,AuxList)),
          if
            length(Listaux) >= 5 ->
              {NewList,_} = lists:split(5,Listaux);
            true ->
              NewList = Listaux
          end,
          UserList = [string:join([Username,integer_to_list(Score)], " ") || {Username,Score} <- NewList],
          Res = string:join(UserList, " | "),
          gen_tcp:send(Sock, string:join([Res, "\n"], ""))
      end;
    ["join", Info] ->
      io:fwrite(String),
      [User, Pass] = string:split(Info, " "),
      invoke({join,User,Pass}),
      receive
        {done,Party} ->
          gen_tcp:send(Sock, "Entrou na queue\n"),
          clientGame(Sock, Party, User);
        auth_fail ->
          gen_tcp:send(Sock, "invalid_auth\n")
      end;
    ["update",Info]->
      io:fwrite(String),
      [User,Resto]=string:split(Info," "),
      [Level,Resto2]=string:split(Resto," "),
      [Score,NPartidas]=string:split(Resto2," "),
      invoke({update,User,Level,Score,NPartidas}),
      receive
        done->
          io:fwrite("Mapa foi atualizado")
      end;
    _ ->
      io:fwrite(String),
      io:fwrite("Incorrect syntax in tcp request.\n")
  end.


% GAME ------------------------------------------------------------------------------------------------------------------------------------


member(_, []) -> false;
member({User,Level,Score,NPartidas,From}, [H|T]) ->
  case H of
    {User,Level,Score,NPartidas,From}->member({User,Level,Score,NPartidas,From},T);
    {_,Level,_,_,_} -> true;
    _ -> member({User,Level,Score,NPartidas,From},T)
  end.


party(Queue)->
  receive
    {join, User,Level,Score,NPartidas, From} ->
      From !{done,self()},
      NewQueue = Queue ++ [{User,Level,Score,NPartidas, From}],
      case member({User,Level,Score,NPartidas,From}, NewQueue) of
        true->
          Adversarios=[{U,L,S,N,F} || {U,L,S,N,F} <- NewQueue,L==Level],
          Jogo=spawn(fun()->jogo() end),
          Jogo ! {comeca,Adversarios},
          Nova = [{U,L,S,N,F} || {U,L,S,N,F} <- NewQueue, L /= Level],
          party(Nova);
        false ->
          party(NewQueue)
      end;
    {leave, U, From} ->
      io:fwrite("Left party.\n"),
      From ! leave_done,
      NewQueue = [{User,Level,Score,NPartidas,Pid} || {User,Level,Score,NPartidas,Pid} <- Queue, User /= U],
      party(NewQueue)
  end.


jogo()->
  receive
    {comeca,Adversarios}->
      game(Adversarios),
      jogo()
  end.


game(Players) ->
  io:fwrite("Starting game.\n"),
  %?MODULE ! {start, self()},
  [From ! {start,self()}|| {_User,_,_,_, From} <- Players],
  Self=self(),
  NewPlayers = initGame(Players,2, []),
  spawn(fun() -> receive after 120000 -> Self ! {leave_done,Self} end end), % tempo
  spawn(fun() -> receive after 1000 -> Self ! {displayTime,Self} end end), % timer
  spawn(fun() -> receive after 1000 -> Self ! {gerapowerup,Self} end end),
  gameTimer(NewPlayers,[]).


initGame([],0, _UsedPositions) -> #{};
initGame([{Player,Level,Score,NPartidas, From}| Players],Colorizacao, UsedPositions) ->
  case Colorizacao of
    1->
      Color = blue,
      X = float(1123),
      Y = float(418);
    2->
      Color=yellow,
      X = float(423),
      Y = float(418)
  end,
  case lists:member({X, Y}, UsedPositions) of
    false ->
      case Colorizacao of
        1->
          Pos = {X, Y},
          PlayerMap = initGame(Players,Colorizacao-1, [Pos | UsedPositions]),
          maps:put(Player, {From,Level,Score,NPartidas, Color, Pos, 4.71225,float(0),0,float(3),float(0.5) }, PlayerMap);
        2->
          Pos = {X, Y},
          PlayerMap = initGame(Players,Colorizacao-1, [Pos | UsedPositions]),
          maps:put(Player, {From,Level,Score,NPartidas, Color, Pos, 1.57075,float(0),0,float(3),float(0.5) }, PlayerMap)
      end;
    true ->
      initGame([{Player,Level,Score,NPartidas,From} | Players],Colorizacao, UsedPositions)
  end.


gameTimer(Players,Powerup) ->
  Self = self(),
  spawn(fun() -> receive after 40 -> Self ! timeout end end), % tickrate
  {NewPlayers, NewPowerup} = handleGame(Players, Powerup,Self),
  InfoPowerup=parsePowerup(NewPowerup),
  PlayerInfo = parseGame(maps:to_list(NewPlayers), []),
  PlayerPowerupInfo=string:concat(PlayerInfo,InfoPowerup),
  Info = string:concat(PlayerPowerupInfo, "\n"),
  [From ! Info || {_Player, {From,_,_,_,_, _, _,_,_,_,_}} <- maps:to_list(Players)],
  gameLoop(NewPlayers,NewPowerup).


handleGame(Players,Powerup,Self) ->
  {NewPlayers,FinalPowerup} =powerupCollisions(Powerup, maps:to_list(Players)),
  FinalPlayers  = playerColisions(maps:to_list(NewPlayers),Self),
  {FinalPlayers, FinalPowerup}.


playerColisions([H|T],Jogo)->
  [A|_]=T,
  {Jogador1, {From1, Level1,Score1,NPartidas1,Color1, {X1, Y1},Angle1,_,Pontuacao1,_,_}}=H,
  {Jogador2, {From2, Level2,Score2,NPartidas2,Color2, {X2, Y2},Angle2,_,Pontuacao2,_,_}}=A,
  Player1=H,
  Player2=A,


  % Player 1 deaths
  case math:sqrt(math:pow(X2-X1,2)+math:pow(Y2-Y1,2))=<50 andalso math:fmod(abs(Angle2-Angle1),6)=<1.57075 andalso math:pow(X1 - (X2+math:sin(Angle1)*35),2) + math:pow(Y1 - (Y2+math:cos(Angle1)*35),2) =< 2000 of
    true->
      NewPlayer1=geranovojogador(Jogador1,From1,Color1,Level1,Score1,NPartidas1,Pontuacao1),
      NewPontuacao1=Pontuacao1+1;
    false->
      case X1 < 373 of
        true->
          NewPlayer1=geranovojogador(Jogador1,From1,Color1,Level1,Score1,NPartidas1,Pontuacao1),
          NewPontuacao1=Pontuacao1+1,
          Jogo! {saiudomapa,Jogador1,Score1,NPartidas1,Level1,From1,Jogador2,Score2,NPartidas2,Level2,From2};
        false->
          case X1 > 1173 of
            true->
              NewPlayer1=geranovojogador(Jogador1,From1,Color1,Level1,Score1,NPartidas1,Pontuacao1),
              NewPontuacao1=Pontuacao1+1,
              Jogo! {saiudomapa,Jogador1,Score1,NPartidas1,Level1,From1,Jogador2,Score2,NPartidas2,Level2,From2};
            false->
              case Y1 < 18 of
                true->
                  NewPlayer1=geranovojogador(Jogador1,From1,Color1,Level1,Score1,NPartidas1,Pontuacao1),
                  NewPontuacao1=Pontuacao1+1,
                  Jogo! {saiudomapa,Jogador1,Score1,NPartidas1,Level1,From1,Jogador2,Score2,NPartidas2,Level2,From2};
                false->
                  case Y1 > 818 of
                    true->
                      NewPlayer1=geranovojogador(Jogador1,From1,Color1,Level1,Score1,NPartidas1,Pontuacao1),
                      NewPontuacao1=Pontuacao1+1,
                      Jogo! {saiudomapa,Jogador1,Score1,NPartidas1,Level1,From1,Jogador2,Score2,NPartidas2,Level2,From2};
                    false->
                      NewPontuacao1=Pontuacao1,
                      NewPlayer1=Player1
                  end
              end
          end
      end
  end,


  % Player 2 deaths
  case math:sqrt(math:pow(X2-X1,2)+math:pow(Y2-Y1,2))=<50 andalso math:fmod(abs(Angle1-Angle2),6)=<1.57075 andalso math:pow(X2 - (X1+math:sin(Angle1)*35),2) + math:pow(Y2 - (Y1+math:cos(Angle1)*35),2) =< 2000 of
    true->
      NewPlayer2=geranovojogador(Jogador2,From2,Color2,Level2,Score2,NPartidas2,Pontuacao2),
      NewPontuacao2=Pontuacao2+1;
    false->
      case X2 < 373 of
        true->
          NewPlayer2=geranovojogador(Jogador2,From2,Color2,Level2,Score2,NPartidas2,Pontuacao2),
          NewPontuacao2=Pontuacao2+1,
          Jogo! {saiudomapa,Jogador2,Score2,NPartidas2,Level2,From2,Jogador1,Score1,NPartidas1,Level1,From1};
        false->
          case X2 > 1173 of
            true->
              NewPlayer2=geranovojogador(Jogador2,From2,Color2,Level2,Score2,NPartidas2,Pontuacao2),
              NewPontuacao2=Pontuacao2+1,
              Jogo! {saiudomapa,Jogador2,Score2,NPartidas2,Level2,From2,Jogador1,Score1,NPartidas1,Level1,From1};
            false->
              case Y2 < 18 of
                true->
                  NewPlayer2=geranovojogador(Jogador2,From2,Color2,Level2,Score2,NPartidas2,Pontuacao2),
                  NewPontuacao2=Pontuacao2+1,
                  Jogo! {saiudomapa,Jogador2,Score2,NPartidas2,Level2,From2,Jogador1,Score1,NPartidas1,Level1,From1};
                false->
                  case Y2 > 818 of
                    true->
                      NewPlayer2=geranovojogador(Jogador2,From2,Color2,Level2,Score2,NPartidas2,Pontuacao2),
                      NewPontuacao2=Pontuacao2+1,
                      Jogo! {saiudomapa,Jogador2,Score2,NPartidas2,Level2,From2,Jogador1,Score1,NPartidas1,Level1,From1};
                    false->
                      NewPontuacao2=Pontuacao2,
                      NewPlayer2=Player2
                  end
              end
          end
      end
  end,


  {NewJogador1, {NewFrom1, NewLevel1,NewScore1,NewPartidas1,NewColor1, {NewX1, NewY1},NewAngle1,NewVelocidade1,_,NewVelang1,NewAceleracao1}}=NewPlayer1,
  {NewJogador2, {NewFrom2, NewLevel2,NewScore2,NewPartidas2,NewColor2, {NewX2, NewY2},NewAngle2,NewVelocidade2,_,NewVelang2,NewAceleracao2}}=NewPlayer2,
  Resultado1={NewJogador1, {NewFrom1, NewLevel1,NewScore1,NewPartidas1,NewColor1, {NewX1, NewY1},NewAngle1,NewVelocidade1,NewPontuacao1,NewVelang1,NewAceleracao1}},
  Resultado2={NewJogador2, {NewFrom2, NewLevel2,NewScore2,NewPartidas2,NewColor2, {NewX2, NewY2},NewAngle2,NewVelocidade2,NewPontuacao2,NewVelang2,NewAceleracao2}},
  Jogadores=maps:merge(maps:from_list([Resultado1]),maps:from_list([Resultado2])),
  Jogadores.


geranovojogador(Username,From,Cor,Level,Score,NPartidas,Pontuacao)->
  X = float(rand:uniform(700) + 400),
  Y = float(rand:uniform(400) + 400),
  Angle=1.57075,
  Velocidade=float(0),
  Velang=float(3),
  Acelaracao=float(0.5),
  {Username,{From,Level,Score,NPartidas,Cor,{X,Y},Angle,Velocidade,Pontuacao,Velang,Acelaracao}}.


powerupCollisions(Powerup, [H|T]) ->
  [A|_]=T,
  {Jogador1,Powerup1}=powerupCollisionsAux(Powerup, H),
  {Jogador2,Powerup2}=powerupCollisionsAux(Powerup, A),
  Jogadores=maps:merge(maps:from_list([Jogador1]),maps:from_list([Jogador2])),
  case Powerup1 of
    []->
      {Jogadores,[]};
    _->
      case Powerup2 of
        []->
          {Jogadores,[]};
        _->
          {Jogadores,Powerup1}
      end
  end.


powerupCollisionsAux(Powerup,Player)->
  case Powerup of
    []->
      {Player,[]};
    [PowerupX,PowerupY,PowerupCor]->
      {Username, {From, Level,Score,NPartidas,Color, {X, Y},Angle2,Velocidade,Pontuacao,Velang,Aceleracao}}=Player,
      case PowerupCor of
        red->
          case distancia(X,PowerupX,Y,PowerupY)=<35 of
            true->
              io:fwrite("apanhou vermelho"),
              Velang1 = float(3),
              Aceleracao1= float(0.5),
              PickPowerup=[];
            false->
              PickPowerup=Powerup,
              Velang1 = Velang,
              Aceleracao1= Aceleracao
          end;

        green->
          case distancia(X,PowerupX,Y,PowerupY)=<35 of
            true->
              io:fwrite("apanhou verde"),
              Velang1 = Velang*2,
              Aceleracao1=Aceleracao,
              PickPowerup=[];
            false->
              PickPowerup=Powerup,
              Velang1 = Velang,
              Aceleracao1= Aceleracao
          end;

        blue->
          case distancia(X,PowerupX,Y,PowerupY)=<35 of
            true->
              io:fwrite("apanhou azul"),
              Aceleracao1 = Aceleracao *1.5,
              Velang1=Velang,
              PickPowerup=[];
            false->
              PickPowerup=Powerup,
              Velang1 = Velang,
              Aceleracao1= Aceleracao
          end
      end,
      case Aceleracao1-0.009>float(0.5) of
        true->
          Aceleracao2=Aceleracao1-0.009;
        false->
          Aceleracao2=float(0.5)
      end,
      case Aceleracao2>5*float(0.5)of
        true->
          Aceleracao3=5*float(0.5);
        false->
          Aceleracao3=Aceleracao2
      end,
      case Velang1-0.009>float(3) of
        true->
          Velang2=Velang1-0.009;
        false->
          Velang2=float(3)
      end,
      case Velang2>5*float(3) of
        true->
          Velang3=5*float(3);
        false->
          Velang3=Velang2
      end,
      {{Username, {From, Level,Score,NPartidas,Color, {X, Y},Angle2,Velocidade,Pontuacao,Velang3,Aceleracao3}},PickPowerup}
  end.


distancia(X,PowerupX,Y,PowerupY)->
  (math:sqrt(math:pow(X-PowerupX,2)+math:pow(Y-PowerupY,2))).


parseGame([], List) -> string:join(List, "|");
parseGame([{Player, {_From,Level,Score,_, Color, {X, Y},Angle,_,Pontuacao,_,_}} | Tail], List) ->
  InfoPlayer = string:join([Player,integer_to_list(Level),integer_to_list(Score),integer_to_list(Pontuacao), atom_to_list(Color), float_to_list(X), float_to_list(Y), float_to_list(Angle)], " "),
  parseGame(Tail, [InfoPlayer | List]).


parsePowerup(Powerup)->
  case Powerup of
    []->
      "|Nao ha powerup";
    [X,Y,Color]->
      Frase=string:concat("|",string:join([float_to_list(X),float_to_list(Y),atom_to_list(Color)]," ")),
      Frase
  end.


gerapowerup()->
  X = float(rand:uniform(600) + 400),
  Y = float(rand:uniform(400) + 400),
  case rand:uniform(3) of
    1 -> Color = red;
    2 -> Color = green;
    3 -> Color = blue
  end,
  [X, Y, Color].


gameLoop(Players,Powerup) ->
  receive
    {displayTime,Jogo}->
      io:fwrite("Tempo"),
      [From ! currTime || {_, {From,_,_,_, _, _,_,_,_,_,_}} <- maps:to_list(Players)],
      spawn(fun() -> receive after 1000 -> Jogo  ! {displayTime,Jogo} end end), % timer
      gameLoop(Players,Powerup);
    {gerapowerup,Jogo}->
      NewPowerup=gerapowerup(),
      io:fwrite("Gerou Power"),
      spawn(fun() -> receive after 8000 -> Jogo  ! {gerapowerup,Jogo} end end),
      gameLoop(Players,NewPowerup);
    {leave_done,Jogo}->
      case overtime(maps:to_list(Players)) of
        true->
          io:fwrite("Overtime\n"),
          spawn(fun() -> receive after 500 -> Jogo ! {leave_done,Jogo} end end),
          [From ! prolongamento || {_, {From,_,_,_, _, _,_,_,_,_,_}} <- maps:to_list(Players)],
          gameLoop(Players,Powerup);
        false->
          io:fwrite("Terminou o jogo\n"),
          [From ! {game_done,Players}||{_, {From,_,_,_, _, _,_,_,_,_,_}} <- maps:to_list(Players)]
      end;
    {saiudomapa,Nomeperdeu,Scoreperdeu,NPartidasperdeu,Nivelperdeu,Fromperdeu,Nomeganhou,Scoreganhou,NPartidasganhou,Nivelganhou,Fromganhou}->
      Fromganhou! {inimigosaiudomapa,Nomeganhou,Scoreganhou,NPartidasganhou,Nivelganhou},
      Fromperdeu! {saistedomapa,Nomeperdeu,Scoreperdeu,NPartidasperdeu,Nivelperdeu};
    timeout ->
      gameTimer(Players,Powerup);
    {leave,Username} ->
      io:fwrite("Gameloop saiu\n"),
      [From ! {rage_quit,Level,Score,NPartidas} || {Player, {From,Level,Score,NPartidas, _, _,_,_,_,_,_}} <- maps:to_list(Players), Username /= Player];
    erro->
      io:fwrite("\nOcorreu um erro\n"),
      [From ! erro || {_, {From,_,_,_, _, _,_,_,_,_,_}} <- maps:to_list(Players)];
    {Info, _From} ->
      % io:fwrite("Gameloop info"),
      NewPlayers = handleInput(Players, Info),
      gameLoop(NewPlayers,Powerup)
  end.


overtime([H|T])->
  [A|_]=T,
  {_, {_,_,_,_,_, _,_,_,Pontuacao1,_,_}}=H,
  {_, {_,_,_,_,_, _,_,_,Pontuacao2,_,_}}=A,
  case Pontuacao1==Pontuacao2 of
    true->
      true;
    false->
      false
  end.


handleInput(Players, {Username, W, A, D}) ->
  Res = maps:get(Username, Players),
  Rotacao=float(0.05),
  Atrito=float(0.1),
  case Res of
    {badmap, _} -> Players;
    {badkey, _} -> Players;
    {From,Level,Score,NPartidas, Color, {OldX, OldY},Angle,Velo,Pontuacao,Velang,Aceleracao} ->
      case W of
        "true"->
          Velocidade=abs(Velo-Atrito)+Aceleracao;
        "false"->
          Velocidade=abs(Velo-Atrito)
      end,
      case A of
        "true"->
          Angle1=math:fmod((Angle+(Rotacao*Velang)),6.283);
        "false"->
          Angle1=Angle
      end,

      case D of
        "true\r"->
          Angle2=math:fmod((Angle1-(Rotacao*Velang)),6.283);
        "false\r"->
          Angle2=Angle1
      end,

      X=OldX+(Velocidade*math:sin(Angle2)),
      Y=OldY+(Velocidade*math:cos(Angle2)),
      maps:update(Username, {From, Level,Score,NPartidas,Color, {X, Y},Angle2,Velocidade,Pontuacao,Velang,Aceleracao}, Players)
  end.


clientGame(Sock, Party, Username) ->
  receive
    leave_done ->
      gen_tcp:send(Sock, "Saiu da Queue\n"),
      client(Sock);
    {tcp, _, Data} ->
      [DataString, _] = string:split(Data, "#"),
      case DataString of
        "leave" -> Party ! {leave, Username, self()};
        _ -> io:fwrite("Incorrect syntax in tcp request.\n")
      end,
      clientGame(Sock, Party, Username);
    {tcp_closed, _} ->
      Party ! {leave, Username, self()};
    {tcp_error, _} ->
      Party ! {leave, Username, self()};
    {start, Jogo} ->
      %  io:fwrite("enviou start"),
      gen_tcp:send(Sock, "start\n"),
      clientGameLoop(Sock, Party,Jogo, Username);
    _ ->
      clientGame(Sock, Party, Username)
  end.


clientGameLoop(Sock, Party,Jogo,Username) ->
  receive
    {game_done,Players} ->
      Res=maps:get(Username,Players),
      {_,Level1,Score1,NPartidas1, _, _,_,_,Pontuacao1,_,_}=Res,
      [{Player2,Pontuacao2,NPartidas2,Level2,Score2}]=[{Player,Pontuaca,Npartidas,Level,Score} || {Player, {_,Level,Score,Npartidas, _, _,_,_,Pontuaca,_,_}} <- maps:to_list(Players), Username /= Player],
      NewPartidas1=NPartidas1,
      NewPartidas2=NPartidas2,
      case Pontuacao1>Pontuacao2 of
        true->
          NovoNivel1=Level1,
          NovoScore1=Score1,
          Resultado="You Lost",
          NovoScore2=Score2+1,
          case 2*Level2==NPartidas2+1 of
            true->
              NewPartidas2=0,
              NovoNivel2=Level2+1;
            false->
              NewPartidas2=NPartidas2+1,
              NovoNivel2=Level2
          end;
        false->
          Resultado="You Won",
          NovoScore2=Score2,
          NovoNivel2=Level2,
          NovoScore1=Score1+1,
          case 2*Level1==NPartidas1+1 of
            true->
              NewPartidas1=0,
              NovoNivel1=Level1+1;
            false->
              NewPartidas1=NPartidas1+1,
              NovoNivel1=Level1
          end
      end,
      Mensagem="update#"++Username++" "++integer_to_list(NovoNivel1)++" "++integer_to_list(NovoScore1)++" "++integer_to_list(NewPartidas1)++"|update#"++Player2++" "++integer_to_list(NovoNivel2)++" "++integer_to_list(NovoScore2)++" "++integer_to_list(NewPartidas2),
      io:fwrite(Mensagem),
      case Resultado of
        "You Lost"->
          gen_tcp:send(Sock, Resultado++"|"++Mensagem ++"\n"),
          client(Sock);
        "You Won"->
          gen_tcp:send(Sock, Resultado++"|"++Mensagem ++"\n"),
          client(Sock)
      end;
    prolongamento->
      gen_tcp:send(Sock,"Overtime\n");
    currTime ->
      gen_tcp:send(Sock,"TIME\n");
    {rage_quit,Level,Score,NPartidas} ->
      case 2*Level==NPartidas+1 of
        true->
          NewPartidas=0,
          NewLevel=Level+1;
        false->
          NewPartidas=NPartidas+1,
          NewLevel=Level
      end,
      Mensagem="update#"++Username++" "++integer_to_list(NewLevel)++" "++integer_to_list(Score+1)++" "++integer_to_list(NewPartidas),
      gen_tcp:send(Sock, "You Won|"++Mensagem++"|"++Mensagem++"\n"),
      client(Sock);
    {inimigosaiudomapa,Username,Score,NPartidas,Level}->
      case 2*Level==NPartidas+1 of
        true->
          NewPartidas=0,
          NewLevel=Level+1;
        false->
          NewPartidas=NPartidas+1,
          NewLevel=Level
      end,
      Mensagem="update#"++Username++" "++integer_to_list(NewLevel)++" "++integer_to_list(Score+1)++" "++integer_to_list(NewPartidas),
      gen_tcp:send(Sock, "You Won|"++Mensagem++"|"++Mensagem++"\n"),
      client(Sock);
    {saistedomapa,Username,Score,NPartidas,Level}->
      Mensagem="update#"++Username++" "++integer_to_list(Level)++" "++integer_to_list(Score)++" "++integer_to_list(NPartidas),
      gen_tcp:send(Sock, "You Lost|"++Mensagem++"|"++Mensagem++"\n"),
      client(Sock);
    erro->
      gen_tcp:send(Sock, "Ocorreu algum erro\n"),
      client(Sock);
    {tcp, _, Data} ->
      DataString = string:trim(Data, trailing, "\n"),
      case string:split(DataString, "#") of
        ["input", Info] ->
          [W,A,D] = string:split(Info, " ", all),
          Jogo ! {{Username, W, A, D}, self()};
        ["leave", _] ->
          gen_tcp:send(Sock, "\nA sair do jogo\n"),
          Jogo ! {leave, Username, self()}
      end,
      clientGameLoop(Sock, Party,Jogo, Username);
    {tcp_closed, _} -> Jogo ! {leave,Username};
    {tcp_error, _} -> Jogo! erro;
    Info ->
      gen_tcp:send(Sock, Info)
  end,
  clientGameLoop(Sock, Party,Jogo, Username).