
FROM openjdk:11.0.11-jre

ARG PROJECT_VERSION=0.1.0
LABEL maintainer="ecommerce-microservice-backend"
LABEL version="${PROJECT_VERSION}"

# Create app directory
RUN mkdir -p /home/app && \
    groupadd -g 1001 appuser && \
    useradd -r -u 1001 -g appuser appuser && \
    chown -R appuser:appuser /home/app

WORKDIR /home/app

# Environment variables
ENV SPRING_PROFILES_ACTIVE=dev
ENV JAVA_OPTS="-Xmx512m -Xms256m"

# Copy JAR file
COPY target/api-gateway-v${PROJECT_VERSION}.jar api-gateway.jar

# Change ownership to non-root user
RUN chown appuser:appuser api-gateway.jar

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Entry point
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Dspring.profiles.active=${SPRING_PROFILES_ACTIVE} -jar api-gateway.jar"]


