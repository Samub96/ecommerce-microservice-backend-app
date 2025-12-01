
# Build stage
FROM eclipse-temurin:11-jdk AS build

WORKDIR /workspace/app

# Copy maven files first for better layer caching
COPY cloud-config/pom.xml .
COPY cloud-config/mvnw .
COPY cloud-config/mvnw.cmd .
COPY cloud-config/.mvn .mvn

# Download dependencies for better layer caching
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY cloud-config/src src

# Build the application
RUN ./mvnw clean package -DskipTests

# Extract JAR layers for better Docker layer caching
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../cloud-config-v*.jar)

# Runtime stage
FROM eclipse-temurin:11-jre

# Create non-root user for security
RUN groupadd -r cloudconfig && useradd -r -g cloudconfig cloudconfig

# Install security updates
RUN apt-get update && \
    apt-get install -y --no-install-recommends dumb-init curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/app

# Copy JAR layers from build stage
COPY --from=build --chown=cloudconfig:cloudconfig /workspace/app/target/dependency/BOOT-INF/lib lib
COPY --from=build --chown=cloudconfig:cloudconfig /workspace/app/target/dependency/META-INF META-INF
COPY --from=build --chown=cloudconfig:cloudconfig /workspace/app/target/dependency/BOOT-INF/classes .

# Set up environment
ENV SPRING_PROFILES_ACTIVE=kubernetes \
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:+UseStringDeduplication"

USER cloudconfig

EXPOSE 9296

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:9296/actuator/health || exit 1

ENTRYPOINT ["dumb-init", "java"] 
CMD ["-cp", ".:lib/*", "com.microservices.cloudconfig.CloudConfigApplication"]

# Set working directory
WORKDIR /app

# Copy the extracted layers from builder stage
COPY --from=builder --chown=appuser:appgroup workspace/app/dependencies/ ./
COPY --from=builder --chown=appuser:appgroup workspace/app/spring-boot-loader/ ./
COPY --from=builder --chown=appuser:appgroup workspace/app/snapshot-dependencies/ ./
COPY --from=builder --chown=appuser:appgroup workspace/app/application/ ./

# Switch to non-root user
USER appuser

# Environment variables for JVM optimization
ENV JAVA_OPTS="-XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=75.0 \
    -XX:+UseG1GC \
    -XX:+UseStringDeduplication \
    -Djava.security.egd=file:/dev/./urandom \
    -Dspring.jmx.enabled=false"

ENV SPRING_PROFILES_ACTIVE=kubernetes

# Expose port
EXPOSE 9296

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:9296/actuator/health || exit 1

# Entry point with optimized JVM settings
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Dspring.profiles.active=${SPRING_PROFILES_ACTIVE} org.springframework.boot.loader.JarLauncher"]



