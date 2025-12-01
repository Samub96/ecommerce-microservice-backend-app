
# Build stage
FROM maven:3-eclipse-temurin-11 AS build

WORKDIR /workspace/app

# Copy parent pom first
COPY pom.xml /workspace/

# Copy maven files first for better layer caching
COPY proxy-client/pom.xml .

# Download dependencies for better layer caching
RUN mvn dependency:go-offline -B

# Copy source code
COPY proxy-client/src src

# Build the application
RUN mvn clean package -DskipTests

# Extract JAR layers for better Docker layer caching
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../proxy-client-v*.jar)

# Runtime stage
FROM eclipse-temurin:11-jre

# Create non-root user for security
RUN groupadd -r proxyclient && useradd -r -g proxyclient proxyclient

# Install security updates
RUN apt-get update && \
    apt-get install -y --no-install-recommends dumb-init curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/app

# Copy JAR layers from build stage
COPY --from=build --chown=proxyclient:proxyclient /workspace/app/target/dependency/BOOT-INF/lib lib
COPY --from=build --chown=proxyclient:proxyclient /workspace/app/target/dependency/META-INF META-INF
COPY --from=build --chown=proxyclient:proxyclient /workspace/app/target/dependency/BOOT-INF/classes .

# Set up environment
ENV SPRING_PROFILES_ACTIVE=kubernetes \
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:+UseStringDeduplication"

USER proxyclient

EXPOSE 8900

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8900/actuator/health || exit 1

ENTRYPOINT ["dumb-init", "java"] 
CMD ["-cp", ".:lib/*", "com.microservices.proxyclient.ProxyClientApplication"]