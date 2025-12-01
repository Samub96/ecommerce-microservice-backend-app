
# Build stage
FROM eclipse-temurin:11-jdk AS build

WORKDIR /workspace/app

# Copy maven files first for better layer caching
COPY api-gateway/pom.xml .
COPY api-gateway/mvnw .
COPY api-gateway/mvnw.cmd .
COPY api-gateway/.mvn .mvn

# Make mvnw executable
RUN chmod +x ./mvnw

# Download dependencies for better layer caching
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY api-gateway/src src

# Build the application
RUN ./mvnw clean package -DskipTests

# Extract JAR layers for better Docker layer caching
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../api-gateway-v*.jar)

# Runtime stage
FROM eclipse-temurin:11-jre

# Create non-root user for security
RUN groupadd -r apigateway && useradd -r -g apigateway apigateway

# Install security updates
RUN apt-get update && \
    apt-get install -y --no-install-recommends dumb-init curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/app

# Copy JAR layers from build stage
COPY --from=build --chown=apigateway:apigateway /workspace/app/target/dependency/BOOT-INF/lib lib
COPY --from=build --chown=apigateway:apigateway /workspace/app/target/dependency/META-INF META-INF
COPY --from=build --chown=apigateway:apigateway /workspace/app/target/dependency/BOOT-INF/classes .

# Set up environment
ENV SPRING_PROFILES_ACTIVE=kubernetes \
    JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:+UseStringDeduplication"

USER apigateway

EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["dumb-init", "java"] 
CMD ["-cp", ".:lib/*", "com.microservices.apigateway.ApiGatewayApplication"]


