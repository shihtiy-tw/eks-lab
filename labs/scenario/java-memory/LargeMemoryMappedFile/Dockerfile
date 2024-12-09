FROM openjdk:17
COPY . /tmp
WORKDIR /tmp
ENTRYPOINT ["java", "-XX:NativeMemoryTracking=detail", "-XX:+UseContainerSupport","-Xms512m", "-Xmx2048m", "LargeMemoryMappedFile.java"]
