import java.io.IOException;
import java.util.List;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

import java.io.IOException;
import java.util.List;

public class Auxiliar implements Runnable{

    private Connection_manager tcp;
    private Informacao info;
    private Jogador player;
    private Jogador enemy;

    public Auxiliar(Connection_manager tcp, Informacao variavel,Jogador player,Jogador enemy){
        this.tcp = tcp;
        this.info = variavel;
        this.player=player;
        this.enemy=enemy;
    }

    public void run(){
        while (true) {
            try {
                info.lock.lock();
                info.waitPostman.await();
                switch(info.opcao) {
                    case LOGIN:
                        //tcp.login(info.username, info.password);
                        System.out.println(info.opcao);
                        info.answer=tcp.login(info.username, info.password);
                        if (info.answer.compareTo("Incorrect username or password.")==0) {
                            info.response=Response.ERROR;
                            info.waitScreen.signal();
                        }else{
                            info.response = Response.DONE;}
                        break;

                    case CREATE_USER:
                        System.out.println(info.opcao);
                        info.answer =tcp.create_account(info.username, info.password);
                        info.response = Response.DONE;
                        break;

                    case REMOVE_USER:
                        System.out.println(info.opcao);
                        info.answer = tcp.remove_account(info.username, info.password);
                        info.response = Response.DONE;
                        break;
                    case LOGOUT:
                        System.out.println(info.opcao);
                        info.answer = tcp.logout(info.username, info.password);
                        info.response = Response.DONE;
                        break;
                    case LEADER:
                        System.out.println(info.opcao);
                        String resposta=tcp.leaderboard();
                        String[] aux = (resposta).split("\\|");
                        int c = 0;
                        for(String i : aux){
                            i = i.strip();
                            info.leaderboardNames[c] = i.split(" ")[0];
                            info.leaderboardScores[c] = i.split(" ")[1];
                            c++;
                        }
                        info.response = Response.DONE;
                        break;
                    case QUEUE:
                        System.out.println(info.opcao);
                        tcp.join(info.username, info.password);
                        info.response = Response.DONE;
                        new Thread(()->{
                            try {
                                String response = tcp.receive();
                                if(response.equals("start")){
                                    info.answer=response;
                                    System.out.println(info.answer);
                                    info.opcao = State.GAME;
                                }
                            } catch (IOException e) {
                                throw new RuntimeException(e);
                            }
                        }).start();
                        break;
                    case GAME:
                        System.out.println(info.opcao);
                        String response = tcp.receive();
                        if(response.equals("TIME")) {
                            player.time = player.time - 1;
                            System.out.println("TIME: " + player.time);
                            info.response = Response.DONE;
                        }else if(response.equals("Overtime")) {
                            info.prolongamento ="Overtime";
                            info.response = Response.DONE;
                            player.time = 0;
                        } else{
                            System.out.println(response);
                            String[] positionsString = response.split("\\|");
                            int N=positionsString.length;
                            if(positionsString[0].equals("You Lost")) {
                                System.out.println(positionsString[1]);
                                tcp.send(positionsString[1]);
                                info.opcao = State.LOGGED;
                                info.response = Response.SWITCH;
                                info.answer = "You Lost";
                                player.time = 120;
                                info.prolongamento="";
                            }else if(positionsString[0].equals("You Won")){
                                System.out.println(positionsString[1]);
                                tcp.send(positionsString[1]);
                                info.opcao = State.LOGGED;
                                info.response = Response.SWITCH;
                                info.answer = "You Won";
                                player.time = 120;
                                info.prolongamento="";
                            }else {
                                for (int i=0;i<N; i++) {
                                    String[] pieceInfo = positionsString[i].split(" ");
                                    if (pieceInfo[0].equals(info.username)) {
                                        player.nome = pieceInfo[0];
                                        player.nivel = Integer.parseInt(pieceInfo[1]);
                                        player.partidasganhas=Integer.parseInt(pieceInfo[2]);
                                        player.pontuacao = Integer.parseInt(pieceInfo[3]);
                                        player.cor = pieceInfo[4];
                                        player.x = Float.parseFloat(pieceInfo[5]);
                                        player.y = Float.parseFloat(pieceInfo[6]);
                                        player.angle = Float.parseFloat(pieceInfo[7]);
                                    } else if(i==2) {
                                        if(pieceInfo[0].equals("Nao")){
                                            player.powerupcor = "";
                                        }else {
                                            player.powerupx = Float.parseFloat(pieceInfo[0]);
                                            player.powerupy = Float.parseFloat(pieceInfo[1]);
                                            player.powerupcor = pieceInfo[2];
                                        }
                                    }else{
                                        enemy.nome = pieceInfo[0];
                                        enemy.nivel = Integer.parseInt(pieceInfo[1]);
                                        enemy.partidasganhas=Integer.parseInt(pieceInfo[2]);
                                        enemy.pontuacao = Integer.parseInt(pieceInfo[3]);
                                        enemy.cor = pieceInfo[4];
                                        enemy.x = Float.parseFloat(pieceInfo[5]);
                                        enemy.y = Float.parseFloat(pieceInfo[6]);
                                        enemy.angle = Float.parseFloat(pieceInfo[7]);
                                    }
                                }
                                tcp.enviainput(player.keys);
                                info.response = Response.DONE;
                            }
                        }
                        break;
                    case LEAVE:
                        System.out.println(info.opcao);
                        tcp.sair();
                        info.response = Response.DONE;
                }
                info.waitScreen.signal();
            } catch (InterruptedException | IOException e) {
                throw new RuntimeException(e);
            } finally {
                info.lock.unlock();
            }

        }

    }
}