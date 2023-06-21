import java.io.PrintWriter;
import java.net.Socket;


public class Main {
    public static void main(String[] args) {

        try {
            //for(int i=1;i<=2;i++) {
                Socket socket = new Socket("localhost", 2);
                Connection_manager tcp = new Connection_manager(socket);
                Informacao variavel = new Informacao();
                Jogador player = new Jogador();
                Jogador enemy = new Jogador();
                new Thread(new Menu(variavel,player,enemy)).start();
                new Thread(new Auxiliar(tcp, variavel,player,enemy)).start();
       //     }
        } catch (Exception e) {
            System.out.println(e.getMessage());
        }
    }
}
