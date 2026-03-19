## Guía paso a paso: CI/CD para `curso-devops-api`

Esta guía documenta todo el flujo de **CI/CD** que configuraste para este proyecto:

- **CI (Integración Continua)**:
  - Validar código en cada Pull Request.
  - Construir y testear la aplicación en cada push a `main`.
- **CD (Entrega Continua)**:
  - Construir imagen Docker.
  - Publicar en Docker Hub.
  - Desplegar automáticamente en tu servidor Linux con Docker y Docker Compose.

La idea es que puedas leer este archivo en unos meses y seguir entendiendo **qué hace cada cosa y por qué**.

---

## 1. Requisitos previos

### 1.1. En tu máquina local (desarrollo)

- Git instalado.
- Java 17 instalado.
- Maven disponible (o usar el Maven Wrapper del proyecto).
- Docker instalado (si quieres probar imágenes localmente).

### 1.2. En Docker Hub

- Cuenta en Docker Hub.
- Repositorio creado, por ejemplo: `bladimirriltex/apicontactos`.

### 1.3. En tu servidor Linux

- Distribución Linux (ej. Ubuntu Server).
- Docker instalado y funcionando:

```bash
docker --version
```

- Docker Compose v2 instalado (comando `docker compose`, no `docker-compose`):

```bash
docker compose version
```

- Puertos **80** y **8080** abiertos (firewall + proveedor de hosting).

### 1.4. SSH por llave (sin password)

En tu máquina local (Windows), generas una llave SSH específica para GitHub Actions:

```powershell
ssh-keygen -t ed25519 -C "github-actions" -f $env:USERPROFILE\.ssh\github_actions
```

Esto crea:

- Llave privada: `~/.ssh/github_actions`
- Llave pública: `~/.ssh/github_actions.pub`

Copias la **llave pública** al servidor:

```powershell
Get-Content $env:USERPROFILE\.ssh\github_actions.pub
```

En el servidor:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys   # pegas aquí la llave pública
chmod 600 ~/.ssh/authorized_keys
```

Pruebas que la conexión funciona sin password:

```powershell
ssh -i $env:USERPROFILE\.ssh\github_actions root@TU_IP
```

---

## 2. Artefactos de despliegue

En este proyecto, el despliegue gira alrededor de tres piezas:

1. `Dockerfile` → cómo se construye la imagen de la aplicación.
2. `docker-compose.yml` → cómo se orquestan los contenedores en el servidor.
3. `deploy/nginx/default.conf` → cómo Nginx hace de reverse proxy.

### 2.1. `Dockerfile`

Ubicación: `Dockerfile`

Puntos clave:

- Usa **multi-stage build**: un stage para compilar, otro para ejecutar.
- Primer stage (`build`) usa `eclipse-temurin:17-jdk` + Maven para compilar.
- Segundo stage (`runtime`) usa `eclipse-temurin:17-jre` para ejecutar el JAR.

Fragmento importante:

```12:34:c:\Users\Bladimir\Documents\Cursos\Platzi\DevOps\curso-devops\Dockerfile
FROM eclipse-temurin:17-jdk AS build
RUN apt-get update && apt-get install -y maven && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests --no-transfer-progress

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Por qué así:**

- `dependency:go-offline` + copiar solo `pom.xml` primero → aprovecha la caché de Docker, no redescarga dependencias en cada build.
- Segundo stage sin JDK (solo JRE) → imagen final más pequeña y segura.
- `ENTRYPOINT` en forma de array → el proceso Java recibe señales correctamente (shutdown limpio).

### 2.2. `docker-compose.yml`

Ubicación: `docker-compose.yml`

Define dos servicios:

- `api`: la app Spring Boot (imagen desde Docker Hub).
- `nginx`: reverse proxy que escucha en el puerto 80.

Fragmento:

```1:18:c:\Users\Bladimir\Documents\Cursos\Platzi\DevOps\curso-devops\docker-compose.yml
services:

  api:
    image: bladimirriltex/apicontactos:latest
    container_name: curso-devops-api
    restart: unless-stopped
    ports:
      - "8080:8080"

  nginx:
    image: nginx:alpine
    container_name: curso-devops-nginx
    restart: unless-stopped
    depends_on:
      - api
    ports:
      - "80:80"
    volumes:
      - ./deploy/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
```

**Por qué así:**

- `restart: unless-stopped` → los contenedores se levantan solos después de reiniciar el servidor.
- `depends_on: [api]` → asegura que la app esté arriba antes que Nginx.
- `./deploy/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro` → Nginx usa tu configuración personalizada (no la default).

### 2.3. `deploy/nginx/default.conf`

Ubicación: `deploy/nginx/default.conf`

Hace que todas las peticiones que entran por el **puerto 80** vayan al servicio `api` en el puerto 8080 dentro de la red de Docker.

Fragmento:

```1:16:c:\Users\Bladimir\Documents\Cursos\Platzi\DevOps\curso-devops\deploy\nginx\default.conf
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://api:8080;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Por qué así:**

- `proxy_pass http://api:8080;` → `api` es el nombre del servicio de Compose, Docker resuelve su IP internamente.
- Cabeceras `X-Forwarded-*` → la app conoce la IP real del cliente y si la petición original fue HTTP o HTTPS.

---

## 3. Secrets en GitHub (credenciales)

En tu repositorio, ve a:

`Settings → Secrets and variables → Actions`

Y crea estos **Repository secrets**:

- `DOCKERHUB_USERNAME` → tu usuario en Docker Hub.
- `DOCKERHUB_TOKEN` → access token de Docker Hub (con permisos *Read & Write*).
- `SERVER_HOST` → IP pública del servidor donde despliegas.
- `SERVER_USER` → usuario SSH del servidor (ej. `root`).
- `SERVER_SSH_KEY` → contenido completo de la llave privada `github_actions` (NO la `.pub`).
- `SERVER_SSH_PORT` → opcional, si usas un puerto diferente de 22.

Estos secrets son usados por los workflows para:

- Loguearse en Docker Hub.
- Conectarse por SSH al servidor sin password.

---

## 4. Workflows de GitHub Actions

Tienes tres workflows principales:

1. `pull_request_review.yml` → valida PRs.
2. `ci-cd.yml` → ciclo completo CI/CD en `push main`.
3. `containerDeployment.yml` → build & push manual de imagen.

### 4.1. `pull_request_review.yml` — Validación de PRs

Ubicación: `.github/workflows/pull_request_review.yml`

Se ejecuta en cada **Pull Request hacia `main`**. No despliega nada, solo verifica que:

- El código compile (`mvn clean compile`).
- Los tests pasen (`mvn test`).

Fragmento clave:

```1:35:c:\Users\Bladimir\Documents\Cursos\Platzi\DevOps\curso-devops\.github\workflows\pull_request_review.yml
on:
  pull_request:
    branches:
      - main

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Java 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'maven'

      - name: Build the project
        run: mvn clean compile --no-transfer-progress

      - name: Run tests
        run: mvn test --no-transfer-progress
```

**Objetivo:** No dejar que código roto se mezcle a `main`.

### 4.2. `ci-cd.yml` — CI/CD completo en `push main`

Ubicación: `.github/workflows/ci-cd.yml`

Se ejecuta en cada **push a la rama `main`**. Tiene dos jobs:

1. `build_test_push` → CI.
2. `deploy` → CD.

#### 4.2.1. Job `build_test_push`

Responsabilidades:

- Checkout del código.
- Instalar Java 17.
- Correr tests.
- Construir imagen Docker.
- Loguearse en Docker Hub.
- Subir la imagen con tag `latest`.

Fragmento:

```11:40:c:\Users\Bladimir\Documents\Cursos\Platzi\DevOps\curso-devops\.github\workflows\ci-cd.yml
jobs:
  build_test_push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Java 17
        uses: actions/setup-java@v4
        with:
          java-version: "17"
          distribution: "temurin"
          cache: "maven"

      - name: Run tests
        run: mvn test --no-transfer-progress

      - name: Build Docker image
        run: |
          docker build -t $IMAGE_NAME:latest .

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Push image
        run: |
          docker push $IMAGE_NAME:latest
```

#### 4.2.2. Job `deploy`

Este job solo corre si `build_test_push` terminó bien (`needs: build_test_push`).

Responsabilidades:

- Preparar la llave SSH.
- Crear directorios remotos.
- Copiar `docker-compose.yml` y `default.conf` al servidor.
- Ejecutar `docker compose pull` y `docker compose up -d`.

Fragmento:

```42:84:c:\Users\Bladimir\Documents\Cursos\Platzi\DevOps\curso-devops\.github\workflows\ci-cd.yml
deploy:
  runs-on: ubuntu-latest
  needs: build_test_push
  steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup SSH key
      env:
        SSH_KEY: ${{ secrets.SERVER_SSH_KEY }}
      run: |
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        printf '%s\n' "$SSH_KEY" > ~/.ssh/id_ed25519
        chmod 600 ~/.ssh/id_ed25519
        ssh-keyscan -p ${{ env.SSH_PORT }} ${{ secrets.SERVER_HOST }} >> ~/.ssh/known_hosts

    - name: Create remote directories
      run: |
        ssh -p ${{ env.SSH_PORT }} -i ~/.ssh/id_ed25519 \
          ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_HOST }} \
          "mkdir -p /opt/curso-devops-api/deploy/nginx"

    - name: Copy deployment files to server
      run: |
        scp -P ${{ env.SSH_PORT }} -i ~/.ssh/id_ed25519 \
          docker-compose.yml \
          ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_HOST }}:/opt/curso-devops-api/docker-compose.yml

        scp -P ${{ env.SSH_PORT }} -i ~/.ssh/id_ed25519 \
          deploy/nginx/default.conf \
          ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_HOST }}:/opt/curso-devops-api/deploy/nginx/default.conf

    - name: Deploy on server (pull + up)
      run: |
        ssh -p ${{ env.SSH_PORT }} -i ~/.ssh/id_ed25519 \
          ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_HOST }} \
          "cd /opt/curso-devops-api && \
           docker login -u '${{ secrets.DOCKERHUB_USERNAME }}' -p '${{ secrets.DOCKERHUB_TOKEN }}' && \
           docker compose pull && \
           docker compose up -d --remove-orphans && \
           docker image prune -f"
```

### 4.3. `containerDeployment.yml` — Build & Push manual

Ubicación: `.github/workflows/containerDeployment.yml`

Se ejecuta **solo manualmente** (`workflow_dispatch`). Hace:

- Compilar el JAR sin tests.
- Construir la imagen Docker.
- Subir la imagen a Docker Hub.

No hace deploy ni toca el servidor.

---

## 5. Flujo completo de CI/CD (resumen)

1. Haces cambios en una rama y abres un **Pull Request**:
   - `pull_request_review.yml` compila y corre tests.
   - Si algo falla, corriges antes de poder mergear.

2. Haces **merge a `main`**:
   - `ci-cd.yml` se dispara.
   - Compila, corre tests, construye imagen Docker, sube a Docker Hub.
   - Luego se conecta al servidor vía SSH, copia los archivos de despliegue y ejecuta `docker compose pull && up -d`.

3. En el servidor:
   - Se levantan/actualizan los contenedores `curso-devops-api` (app) y `curso-devops-nginx` (proxy).
   - Tu API queda disponible:
     - `http://TU_IP:8080/api/v1/health`
     - `http://TU_IP/api/v1/health`
     - Swagger: `http://TU_IP/swagger-ui/index.html`

---

## 6. Cómo depurar si algo falla

1. **Revisar Actions en GitHub**:
   - Ve a la pestaña **Actions**.
   - Abre el workflow fallido.
   - Mira en qué paso falló (build, test, push, SSH, compose, etc.).

2. **Revisar logs en el servidor**:

```bash
cd /opt/curso-devops-api
docker compose ps
docker logs curso-devops-api --tail 100
docker logs curso-devops-nginx --tail 100
```

3. **Comprobar conexión manual**:
   - Desde tu máquina:
     ```bash
     curl http://TU_IP/api/v1/health
     curl http://TU_IP:8080/api/v1/health
     ```

Con esta guía y los comentarios en los archivos, deberías poder entender y mantener todo el flujo de CI/CD de principio a fin.

