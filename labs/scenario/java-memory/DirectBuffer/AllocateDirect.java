import java.nio.ByteBuffer;
import java.util.Random; // Import the Random public class

public class AllocateDirect {
  public static void main(String[] args) {
    System.out.println("Hello World");
    Random random = new Random(); // Create a new Random object

    while (true) {
      // https://youtu.be/c755fFv1Rnk?si=YB89nHMZQVjSVl1P&t=2044
      ByteBuffer.allocateDirect(random.nextInt(10000));
    }
    // try {
    // Thread.currentThread().join();
    // } catch (Exception e) {
    // System.out.println(e);
    // }
  }
}
