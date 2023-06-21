import processing.core.PApplet;
import processing.core.PImage;

import java.io.File;
import javax.sound.sampled.AudioInputStream;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.Clip;
import javax.sound.sampled.*;

enum State {
    MENU,
    CREATE_USER,
    REMOVE_USER,
    LOGGED,
    LOGIN,
    LOGOUT,
    LEADER,
    QUEUE,
    LEAVE,
    GAME,
}
public class Menu extends PApplet implements Runnable{
    PImage button;
    PImage menu;
    PImage leaderboard;
    PImage background;
    PImage arena;
    PImage background2;
    PImage arena2;
    PImage background3;
    PImage arena3;
    PImage background4;
    PImage arena4;
    PImage logo;
    String name;
    String pass;
    String copy;
    int selected;
    Informacao info;
    Jogador player;
    Jogador enemy;
    private State state = State.MENU;
    private int tipomenu;
    int minutes;
    int seconds;
    String filepathMusic = "src/music/music.wav";

    public Menu(Informacao variavel,Jogador player,Jogador enemy){

        this.info= variavel;
        this.player=player;
        this.enemy=enemy;
    }

    public void settings(){
        size(1546,836);
        arena=loadImage("images/arena.jpg");
        background=loadImage("images/background.png");
        button = loadImage("images/button.png");
        menu = loadImage("images/menu.png");
        leaderboard= loadImage("images/leaderboard.png");
        background2=loadImage("images/background2.png");
        arena2=loadImage("images/arena2.png");
        background3=loadImage("images/background3.png");
        arena3=loadImage("images/arena3.jpg");
        background4=loadImage("images/background4.png");
        arena4=loadImage("images/arena4.png");
        logo=loadImage("images/logo.png");
        name="";
        pass="";
        copy="";
        selected=0;
        tipomenu=0;
    }
    public void draw(){
        if (info.answer.equals("start"))state=info.opcao;
        switch(state){
            case MENU:
                tipomenu=0;
                drawMenu();
                break;
            case LOGGED:
                tipomenu=2;
                drawMenu2();
                break;
            case LEADER:
                tipomenu=3;
                drawMenu3();
                break;
            case QUEUE:
                tipomenu=4;
                drawMenu4();
                break;
            case GAME:
                tipomenu=5;
                drawMenu5();
                handleTCPState(State.GAME,State.LOGGED);
                break;
        }
    }

    public void mouseClicked() {
        switch(state){
            case MENU:
                clicker1();

            case LOGGED:
                clicker2();

            case LEADER:
                clicker3();

            case QUEUE:
                clicker4();
        }

    }


    public void keyPressed() {
        if (selected==1){
            if (keyCode!=CONTROL && keyCode!=SHIFT && keyCode!=ALT && keyCode!=UP && keyCode!=DOWN && keyCode!=LEFT && keyCode!=RIGHT && keyCode!=ENTER){
                if (key==BACKSPACE) {
                    copy=name;
                    name="";
                    for(int i=0;i<copy.length()-1;i++) name+=copy.charAt(i);
                    copy="";
                }
                else name+=key;
            }
        }
        if (selected==2){
            if (keyCode!=CONTROL && keyCode!=SHIFT && keyCode!=ALT && keyCode!=UP && keyCode!=DOWN && keyCode!=LEFT && keyCode!=RIGHT && keyCode!=ENTER){
                if (key==BACKSPACE) {
                    copy=pass;
                    pass="";
                    for(int i=0;i<copy.length()-1;i++) pass+=copy.charAt(i);
                    copy="";
                }
                else pass+=key;
            }
        }
        if (state==State.GAME){
            if (key=='w'|| key=='W')
                player.keys[0]=true;
            if (key=='a'|| key=='A')
                player.keys[1]=true;
            if (key=='d'|| key=='D')
                player.keys[2]=true;
        }

    }

    public void keyReleased(){
        if(state==State.GAME) {
            if (key == 'w' || key == 'W')
                player.keys[0] = false;
            if (key == 'a' || key == 'A')
                player.keys[1] = false;
            if (key == 'd' || key == 'D')
                player.keys[2] = false;
        }
    }


    void handleTCPState(State nextState, State errorState) {
        try {
            info.lock.lock();
            info.opcao = state;
            info.waitPostman.signal();
            while (info.response == Response.NOTHING) info.waitScreen.await();

            if (info.response == Response.DONE ) {
                state = nextState;
            }
            else if(info.response == Response.SWITCH ) {
                state = info.opcao;
            }
            else
                state = errorState;
            info.response = Response.NOTHING;
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        } finally {
            info.lock.unlock();
        }
    }


    public void drawMenu(){
        surface.setLocation(-10,0);
        surface.setTitle("Nova Arena");
        image(menu,0,0);
        image(logo,523,29);
        fill(255);
        rect(463,378,620,80);
        rect(463,478,620,80);
        image(button,463,578);
        image(button,783,578);
        textSize(45);
        fill(0);
        text("Log in",555,635);
        text("Create account",790,635);
        fill(0,0,0);
        textSize(60);
        if (selected==1) text(name+"_", 483, 438);
        else text(name, 483, 438);
        for (int i=0;i<pass.length();i++){
            copy+="*";
        }
        if (selected==2) text(copy+"_",483,538);
        else text(copy,483,538);
        copy="";
        textSize(40);
        text(info.answer,50,800);

    }

    public void clicker1(){
        if(mouseX>=463 && mouseX<=1083 && mouseY>=378 && mouseY<=458) selected=1;
        else{  if(mouseX>=463 && mouseX<=1083 && mouseY>=478 && mouseY<=558) selected=2;
        else selected=0;}
        if(mouseX>=463 && mouseX<=763 && mouseY>=578 && mouseY<=658 && tipomenu==0){
            info.username=name;
            info.password=pass;
            state=State.LOGIN;
            handleTCPState(State.LOGGED, State.MENU);
            tipomenu=2;
        }

        if(mouseX>=783 && mouseX<=1083 && mouseY>=578 && mouseY<=658 && tipomenu==0){
            info.username=name;
            info.password=pass;
            state=State.CREATE_USER;
            handleTCPState(State.MENU, State.MENU);
            tipomenu=0;
        }
    }


    public void drawMenu2(){
        surface.setLocation(-10,0);
        surface.setTitle("Nova Arena");
        image(menu,0,0);
        image(logo,523,29);
        image(button,623,378);
        image(button,623,478);
        image(button,623,578);
        image(button,1226,736);
        textSize(45);
        fill(0);
        text("Find a game",660,435);
        text("Leaderboard",654,535);
        text("Log Out",698,635);
        textSize(40);
        text("Remove account",1236,786);
        text(info.answer,50,800);

    }

    public void clicker2(){
        if(mouseX>=623 && mouseX<=923 && mouseY>=378 && mouseY<=458 && tipomenu==2){
            state=State.QUEUE;
            handleTCPState(State.QUEUE, State.LOGGED);
            tipomenu=4;
        }

        if(mouseX>=623 && mouseX<=923 && mouseY>=478 && mouseY<=558 && tipomenu==2){
            state=State.LEADER;
            handleTCPState(State.LEADER, State.LOGGED);
            tipomenu=3;
        }
        if(mouseX>=623 && mouseX<=923 && mouseY>=578 && mouseY<=658 && tipomenu==2){
            info.username=name;
            info.password=pass;
            state=State.LOGOUT;
            handleTCPState(State.MENU, State.LOGGED);
            tipomenu=0;
        }
        if(mouseX>=1226 && mouseX<=1526 && mouseY>=736 && mouseY<=816 && tipomenu==2){
            info.username=name;
            info.password=pass;
            state=State.REMOVE_USER;
            handleTCPState(State.MENU, State.LOGGED);
            tipomenu=0;
        }
    }


    public void drawMenu3(){
        surface.setLocation(-10,0);
        surface.setTitle("Nova Arena");
        image(menu,0,0);
        image(logo,523,29);
        image(button,623,700);
        textSize(45);
        fill(0);
        text("Close",720,755);
        fill(0,255,255);
        image(leaderboard,473,100);
        fill(255);
        rect(473,180,598,80);
        rect(473,260,598,80);
        rect(473,340,598,80);
        rect(473,420,598,80);
        rect(473,500,598,80);
        rect(473,420,80,80);
        rect(473,500,80,80);
        rect(953,180,118,80);
        rect(953,260,118,80);
        rect(953,340,118,80);
        rect(953,420,118,80);
        rect(953,500,118,80);
        fill(255,215,0);
        rect(473,180,80,80);
        fill(192,192,192);
        rect(473,260,80,80);
        fill(205,127,50);
        rect(473,340,80,80);
        fill(0);
        text("Leaderboard",650,155);
        text("1",503,235);
        text("2",503,315);
        text("3",503,395);
        text("4",503,475);
        text("5",503,555);
        text(info.leaderboardNames[0],570,235);
        text(info.leaderboardNames[1],570,315);
        text(info.leaderboardNames[2],570,395);
        text(info.leaderboardNames[3],570,475);
        text(info.leaderboardNames[4],570,555);
        text(info.leaderboardScores[0],1000,235);
        text(info.leaderboardScores[1],1000,315);
        text(info.leaderboardScores[2],1000,395);
        text(info.leaderboardScores[3],1000,475);
        text(info.leaderboardScores[4],1000,555);
    }

    public void clicker3(){
        if(mouseX>=623 && mouseX<=923 && mouseY>=700 && mouseY<=780 && tipomenu==3){
            state=State.LOGGED;
            tipomenu=2;}
    }


    public void drawMenu4(){
        image(menu,0,0);
        image(logo,523,29);
        image(button,623,478);
        image(leaderboard,473,378);
        textSize(45);
        fill(0);
        text("Waiting for game",620,430);
        text("Leave",718,530);
    }

    public void clicker4(){
        if(mouseX>=623 && mouseX<=923 && mouseY>=478 && mouseY<=568 && tipomenu==4){
            state=State.LEAVE;
            handleTCPState(State.LOGGED, State.LOGGED);
            tipomenu=2;
        }
    }


    public void drawMenu5(){
        surface.setLocation(-10,0);
        surface.setTitle("Nova Arena");

        //Background
        for(int i=0;i<1546;i=i+256){
            for(int j=0;j<836;j=j+256){
                if (player.nivel==1) image(background2,i,j);
                if (player.nivel==2) image(background3,i,j);
                if (player.nivel==3) image(background,i,j);
                if (player.nivel>=4) image(background4,i,j);
            }
        }

        for(int i=0;i<4;i=i+1){
            for(int j=0;j<4;j=j+1){
                if (player.nivel==1)image(arena2,373+i*200,18+j*200);
                if (player.nivel==2)image(arena3,373+i*200,18+j*200);
                if (player.nivel==3)image(arena,373+i*200,18+j*200);
                if (player.nivel>=4)image(arena4,373+i*200,18+j*200);
            }
        }

        String nome1 = player.nome;
        float angle1=player.angle;
        float x1 =player.x;
        float y1 =player.y;
        String nome2 = enemy.nome;
        float angle2= enemy.angle;
        float x2 =enemy.x;
        float y2 =enemy.y;
        int score1=enemy.pontuacao;
        int score2=player.pontuacao;

        //Powerups
        if (player.powerupcor.equals("green")){
            fill(0,255,0);
            circle(player.powerupx,player.powerupy,20);
        }
        if (player.powerupcor.equals("blue")){
            fill(0,0,255);
            circle(player.powerupx,player.powerupy,20);
        }
        if (player.powerupcor.equals("red")){
            fill(255,0,0);
            circle(player.powerupx,player.powerupy,20);
        }

        if(player.cor.equals("blue")){
            x2 =player.x;
            y2 =player.y;
            angle2=player.angle;
            score2= enemy.pontuacao;
            nome2=player.nome;
            nome1 = enemy.nome;
            x1 =enemy.x;
            y1 =enemy.y;
            angle1= enemy.angle;
            score1=player.pontuacao;
        }

        //Jogador 1 amarelo
        fill(255,255,0);
        triangle((x1+sin(angle1)*35),(y1+cos(angle1)*35),(x1+sin((float) (angle1+1.57075))*25),(y1+cos((float) (angle1+1.57075))*25),(x1+sin((float) (angle1-1.57075))*25),(y1+cos((float) (angle1-1.57075))*25));
        circle(x1,y1,50);

        //Jogador 2 azul
        fill(0,255,255);
        triangle((x2+sin(angle2)*35),(y2+cos(angle2)*35),(x2+sin((float) (angle2+1.57075))*25),(y2+cos((float) (angle2+1.57075))*25),(x2+sin((float) (angle2-1.57075))*25),(y2+cos((float) (angle2-1.57075))*25));
        circle(x2,y2,50);

        //Pontuação
        fill(130);
        rect(10,360,350,150);
        textSize(60);
        fill(255,255,0);
        text(nome1 + ": " +score1, 15, 418);
        fill(0,255,255);
        text(nome2 + ": " +score2, 15 , 488);

        //Timer
        if (info.prolongamento=="" && player.time>=0) {
            fill(130);
            rect(1260, 380, 200, 100);
            minutes=player.time/60;
            seconds=player.time%60;
            fill(0);
            if (seconds < 10) text(minutes+":0"+seconds,1310,450);
            else text(minutes+":"+seconds,1310,450);
        }else if (player.time>=0){
            fill(130);
            rect(1220, 360, 280, 150);
            fill(255,0,0);
            text("OVERTIME",1230,418);
            minutes=player.time/60;
            seconds=player.time%60;
            fill(0);
            if (seconds < 10) text(minutes+":0"+seconds,1310,488);
            else text(minutes+":"+seconds,1310,488);
        }
    }

    public void run() {
        String[] processingArgs = {"Menu"};
        Menu mySketch = new Menu(this.info,this.player,this.enemy);
        PApplet.runSketch(processingArgs, mySketch);
        PlayMusic(filepathMusic);
    }

    public void PlayMusic(String location) {
        try{
            File musicPath = new File(location);
            if(musicPath.exists()){
                AudioInputStream audioInput = AudioSystem.getAudioInputStream(musicPath);
                Clip clip = AudioSystem.getClip();
                clip.open(audioInput);
                FloatControl gainControl =(FloatControl) clip.getControl(FloatControl.Type.MASTER_GAIN);
                gainControl.setValue(-40.0f);
                clip.start();
                clip.loop(Clip.LOOP_CONTINUOUSLY);
            }
        }catch(Exception e){}
    }


}