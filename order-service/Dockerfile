
# Build stage
FROM openjdk:11-jdk-slim as build

WORKDIR /workspace/app

# Copy maven files first for better layer caching
COPY order-service/pom.xml .
COPY order-service/mvnw .
COPY order-service/mvnw.cmd .
COPY order-service/.mvn .mvn

# Download dependencies for better layer caching
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY order-service/src src

# Build the application
RUN ./mvnw clean package -DskipTests

# Extract JAR layers for better Docker layer caching
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../order-service-v*.jar)

# Runtime stage
FROM openjdk:11.0.11-jre

# Create non-root user for security
RUN groupadd -r orderservice && useradd -r -g orderservice orderservice

# Install security updates
RUN apt-get update && \
    apt-get install -y --no-install-recommends dumb-init && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/app

# Copy JAR layers from build stage
COPY --from=build --chown=orderservice:orderservice /workspace/app/target/dependency/BOOT-INF/lib lib
COPY --from=build --chown=orderservice:orderservice /workspace/app/target/dependency/META-INF META-INF
COPY --from=build --chown=orderservice:orderservice /workspace/app/target/dependency/BOOT-INF/classes .

# Set up environment
ENV SPRING_PROFILES_ACTIVE=kubernetes \
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:+UseStringDeduplication"

USER orderservice

EXPOSE 8300

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8300/actuator/health || exit 1

ENTRYPOINT ["dumb-init", "java"] 
CMD ["-cp", ".:lib/*", "com.microservices.orderservice.OrderServiceApplication"]


