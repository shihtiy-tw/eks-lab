import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.logging.Logger;
import java.util.logging.Level;

public class ReadFile {
  private static final Logger logger = Logger.getLogger(ReadFile.class.getName());

  public static void main(String[] args) {
    new ReadFile().run();
  }

  public void run() {
    while (true) {
      try {
        readFile("/tmp/somefile.txt");
      } catch (Exception e) {
        logger.log(Level.SEVERE, "Something went wrong", e);
      }
    }
  }

  private void readFile(String filePath) throws IOException {
    byte[] fileContent = Files.readAllBytes(Paths.get(filePath));
    // Process the file content here
    logger.info("File read successfully: " + filePath);
  }
}
