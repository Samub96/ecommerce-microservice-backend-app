
# ======================================
# STAGE 1: Build Stage
# ======================================
FROM maven:3.9.6-openjdk-11 AS builder

ARG PROJECT_VERSION=0.1.0

# Set working directory
WORKDIR /app

# Copy pom.xml first for better layer caching
COPY pom.xml .

# Download dependencies (cached layer if pom.xml doesn't change)
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests -B && \
    mv target/favourite-service-v${PROJECT_VERSION}.jar target/favourite-service.jar

# ======================================
# STAGE 2: Runtime Stage
# ======================================
FROM openjdk:11.0.1-jre-slim AS runtime

ARG PROJECT_VERSION=0.1.0

# Create non-root user for security
RUN groupadd -g 1001 app && \
    useradd -r -u 1001 -g app app

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


