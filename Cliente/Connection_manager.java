import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.Socket;

public class Connection_manager implements AutoCloseable {
    private BufferedReader in;
    private PrintWriter out;
    private Socket socket;


    public Connection_manager(Socket socket) throws IOException {
        this.socket=socket;
        this.in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
        this.out = new PrintWriter(socket.getOutputStream());
    }
    public void send(String message) {
        out.println(message);
        out.flush();
    }
    public String receive() throws IOException {
        String message = in.readLine();
        return message;
    }
    public void close() throws IOException {
        socket.close();
    }
    public String login(String username, String password) throws IOException{
        String mensagem="login#"+username+" "+password;
        send(mensagem);
        String response = receive();
        System.out.println(response);
        return response;
    }
    /*public void login(String username, String password) throws IOException{
        String mensagem="login#"+username+" "+password;
        send(mensagem);
        String response = receive();
        System.out.println(response);
    }*/
    public String logout(String username, String password) throws IOException{
        String mensagem="logout#"+username+" "+password;
        send(mensagem);
        String response = receive();
        System.out.println(response);
        return response;
    }
    public String create_account(String username, String password) throws IOException{
        String mensagem="create_account#"+username+" "+password;
        send(mensagem);
        String response = receive();
        System.out.println(response);
        return response;
    }
    public String remove_account(String username, String password) throws IOException{
        String mensagem="close_account#"+username+" "+password;
        send(mensagem);
        String response = receive();
        System.out.println(response);
        return response;
    }
    public String leaderboard() throws IOException {
        String mensagem="leaderboard#";
        send(mensagem);
        String response = receive();
        System.out.println(response);
        return response;
    }
    public void join(String username, String password) throws IOException {
        String mensagem="join#"+username+" "+password;
        send(mensagem);
        // while(true){
        String response = receive();
        System.out.println(response);
        // }
    }
    public void enviainput(boolean[] keys){
        String mensagem="input#"+keys[0]+" "+keys[1]+" "+keys[2];
        System.out.println(mensagem);
        send(mensagem);
    }
    public void sair()throws IOException{
        String mensagem="leave#";
        send(mensagem);
    }
}
