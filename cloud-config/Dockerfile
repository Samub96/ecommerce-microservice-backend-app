
# Multi-stage optimized Dockerfile for Cloud Config
ARG JAVA_VERSION=11
ARG PROJECT_VERSION=0.1.0

# Stage 1: Extract JAR layers for better caching
FROM openjdk:11-jdk AS builder
ARG PROJECT_VERSION
WORKDIR /workspace/app

# Copy the fat JAR
COPY cloud-config/target/cloud-config-v${PROJECT_VERSION}.jar application.jar

# Extract the layers
RUN java -Djarmode=layertools -jar application.jar extract

# Stage 2: Runtime image
FROM openjdk:11.0.1-jre-slim

ARG PROJECT_VERSION=0.1.0
LABEL maintainer="ecommerce-microservice-backend"
LABEL version="${PROJECT_VERSION}"
LABEL service="cloud-config"

# Install curl for health checks and create app user
RUN apt-get update && apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd -g 1001 appgroup && \
    useradd -r -u 1001 -g appgroup appuser

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



