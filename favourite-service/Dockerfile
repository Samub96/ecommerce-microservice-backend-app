
# Build stage
FROM eclipse-temurin:11-jdk AS build

WORKDIR /workspace/app

# Copy maven files first for better layer caching
COPY favourite-service/pom.xml .
COPY favourite-service/mvnw .
COPY favourite-service/mvnw.cmd .
COPY favourite-service/.mvn .mvn

# Make mvnw executable
RUN chmod +x ./mvnw

# Download dependencies for better layer caching
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY favourite-service/src src

# Build the application
RUN ./mvnw clean package -DskipTests

# Extract JAR layers for better Docker layer caching
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../favourite-service-v*.jar)

# Runtime stage
FROM eclipse-temurin:11-jre

# Create non-root user for security
RUN groupadd -r favouriteservice && useradd -r -g favouriteservice favouriteservice

# Install security updates
RUN apt-get update && \
    apt-get install -y --no-install-recommends dumb-init curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/app

# Copy JAR layers from build stage
COPY --from=build --chown=favouriteservice:favouriteservice /workspace/app/target/dependency/BOOT-INF/lib lib
COPY --from=build --chown=favouriteservice:favouriteservice /workspace/app/target/dependency/META-INF META-INF
COPY --from=build --chown=favouriteservice:favouriteservice /workspace/app/target/dependency/BOOT-INF/classes .

# Set up environment
ENV SPRING_PROFILES_ACTIVE=kubernetes \
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:+UseStringDeduplication"

USER favouriteservice

EXPOSE 8800

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8800/actuator/health || exit 1

ENTRYPOINT ["dumb-init", "java"] 
CMD ["-cp", ".:lib/*", "com.microservices.favouriteservice.FavouriteServiceApplication"]

# Create app directory
RUN mkdir -p /home/app && chown -R app:app /home/app

# Set working directory
WORKDIR /home/app

# Switch to non-root user
USER app

# Copy the jar file from builder stage
COPY --from=builder --chown=app:app /app/target/favourite-service.jar favourite-service.jar

# Set environment variables
ENV SPRING_PROFILES_ACTIVE=kubernetes
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:MaxMetaspaceSize=128m"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8900/favourite-service/actuator/health || exit 1

# Expose port
EXPOSE 8900

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Dspring.profiles.active=${SPRING_PROFILES_ACTIVE} -jar favourite-service.jar"]


