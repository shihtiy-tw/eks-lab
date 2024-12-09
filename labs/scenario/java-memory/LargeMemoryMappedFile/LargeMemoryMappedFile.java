
// Provide by my colleague Terry.
import java.io.RandomAccessFile;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.io.File;
import java.util.ArrayList;
import java.util.List;

public class LargeMemoryMappedFile {
  public static void main(String[] args) {
    // Size of each mapping: 1GB
    long mapSize = 1L * 1024 * 1024 * 1024; // 1GB in bytes
    // Total number of mappings
    int numberOfMaps = 2; // Total of 2GB
    File tempFile = null;
    List<MappedByteBuffer> buffers = new ArrayList<>();

    try {
      // Create a temporary file
      tempFile = File.createTempFile("large_mapped_file", ".tmp");

      // Ensure the file is deleted on JVM exit
      tempFile.deleteOnExit();

      // Use RandomAccessFile to operate on the file
      try (RandomAccessFile raf = new RandomAccessFile(tempFile, "rw")) {
        // Get the file channel
        FileChannel fc = raf.getChannel();

        // Create multiple memory mappings
        for (int i = 0; i < numberOfMaps; i++) {
          MappedByteBuffer buffer = fc.map(FileChannel.MapMode.READ_WRITE, i * mapSize, mapSize);
          buffers.add(buffer);

          // Write some data to the mapped memory
          for (long j = 0; j < mapSize; j += 1) {
            buffer.put((byte) (j % 256));
          }
        }

        System.out.println("2GB of memory mapped (in " + numberOfMaps + " x 1GB chunks) and filled with data.");
        System.out.println("Press Enter to exit...");
        System.in.read(); // Wait for user input to observe memory usage

      } catch (Exception e) {
        e.printStackTrace();
      }
    } catch (Exception e) {
      e.printStackTrace();
    } finally {
      // Clean up resources
      buffers.clear();
      // Ensure the temporary file is deleted
      if (tempFile != null && tempFile.exists()) {
        tempFile.delete();
      }
    }
  }
}
