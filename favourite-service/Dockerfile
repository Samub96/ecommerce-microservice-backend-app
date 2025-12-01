
# Build stage
FROM maven:3-eclipse-temurin-11 AS build

WORKDIR /workspace/app

# Copy parent pom first
COPY pom.xml /workspace/

# Copy maven files first for better layer caching
COPY favourite-service/pom.xml .

# Download dependencies for better layer caching
RUN mvn dependency:go-offline -B

# Copy source code
COPY favourite-service/src src

# Build the application
RUN mvn clean package -DskipTests

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