########################################
# Stage 1: Build de la aplicación
########################################
FROM eclipse-temurin:17-jdk AS build

# Instalar Maven en la imagen de build
RUN apt-get update && apt-get install -y maven && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copiar solo el pom primero para aprovechar caché de dependencias
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copiar el código fuente y construir el JAR
COPY src ./src
RUN mvn clean package -DskipTests --no-transfer-progress


########################################
# Stage 2: Imagen ligera de runtime
########################################
FROM eclipse-temurin:17-jre

WORKDIR /app

# Copiar el JAR generado desde la imagen de build
COPY --from=build /app/target/*.jar app.jar

# Puerto por defecto de Spring Boot
EXPOSE 8080

# Comando de arranque de la aplicación
ENTRYPOINT ["java", "-jar", "app.jar"]

