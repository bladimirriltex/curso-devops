# =============================================================================
# MULTI-STAGE BUILD
# Usamos dos stages (etapas) separadas para mantener la imagen final lo más
# pequeña y segura posible. La primera etapa compila, la segunda solo ejecuta.
# Si usáramos una sola imagen con JDK, la imagen final pesaría ~400MB más
# e incluiría herramientas de compilación que no necesitamos en producción.
# =============================================================================

########################################
# Stage 1: Compilación de la aplicación
########################################

# eclipse-temurin es la distribución OpenJDK oficial de Adoptium.
# Usamos la variante 17-jdk porque necesitamos el JDK completo para compilar.
# "AS build" le da un nombre a este stage para referenciar su contenido después.
FROM eclipse-temurin:17-jdk AS build

# Instalamos Maven dentro del contenedor de build.
# El "&&" encadena comandos: actualiza repositorios, instala maven y luego
# borra la caché de apt para no inflar el tamaño de la imagen de build.
RUN apt-get update && apt-get install -y maven && rm -rf /var/lib/apt/lists/*

# Definimos /app como directorio de trabajo dentro del contenedor.
# Todos los COPY y RUN siguientes operarán relativo a esta ruta.
WORKDIR /app

# TRUCO DE CACHÉ DE DOCKER:
# Copiamos PRIMERO solo el pom.xml (declaración de dependencias) y descargamos
# las dependencias antes de copiar el código fuente.
# Así Docker cachea esta capa. Si solo cambia código Java pero no el pom.xml,
# Docker reutiliza la caché y no vuelve a descargar todas las dependencias Maven
# (que pueden pesar cientos de MB). Esto hace los builds mucho más rápidos.
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Ahora sí copiamos el código fuente.
# -DskipTests: los tests ya los corrió el pipeline de CI antes de llegar aquí,
# no necesitamos repetirlos dentro del build de imagen.
COPY src ./src
RUN mvn clean package -DskipTests --no-transfer-progress


########################################
# Stage 2: Imagen ligera de ejecución
########################################

# Aquí usamos eclipse-temurin:17-jre (JRE, no JDK).
# El JRE solo puede EJECUTAR Java, no compilar. Pesa ~200MB menos que el JDK.
# Esta es la imagen que realmente se despliega y corre en el servidor.
FROM eclipse-temurin:17-jre

WORKDIR /app

# Copiamos SOLO el JAR generado en el stage anterior (build).
# El resto de archivos de build (código fuente, Maven, dependencias de compilación)
# NO se incluyen en esta imagen final. Esto la hace más pequeña y segura.
COPY --from=build /app/target/*.jar app.jar

# EXPOSE es documentación: le dice a Docker que la app escucha en 8080.
# No abre el puerto por sí solo; eso lo hace el -p en docker run o el compose.
EXPOSE 8080

# ENTRYPOINT define el comando que se ejecuta cuando arranca el contenedor.
# Usamos forma de array ["java", "-jar", "app.jar"] (forma "exec") porque
# así el proceso Java recibe las señales del SO (SIGTERM) directamente,
# lo que permite que Spring Boot se apague de forma limpia (graceful shutdown).
ENTRYPOINT ["java", "-jar", "app.jar"]
