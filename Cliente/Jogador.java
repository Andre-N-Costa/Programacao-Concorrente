public class Jogador {
    int nivel;
    int pontuacao;
    int partidasganhas;
    float x;
    float y;
    float angle;
    boolean[] keys=new boolean[3];
    String cor;
    String nome;
    String powerupcor;
    float powerupx;
    float powerupy;

    int time;

    public Jogador(){
        this.cor="";
        this.powerupcor="";
        this.keys[0]=false;
        this.keys[1]=false;
        this.keys[2]=false;
        this.time = 120;
    }
}
