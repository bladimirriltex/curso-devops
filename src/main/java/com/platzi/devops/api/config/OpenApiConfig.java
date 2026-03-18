package com.platzi.devops.api.config;

import io.swagger.v3.oas.models.ExternalDocumentation;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.OpenAPI;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI cursoDevopsOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Curso DevOps API")
                        .description("API de ejemplo para el curso de DevOps con Spring Boot")
                        .version("v1.0.0")
                        .contact(new Contact()
                                .name("Equipo DevOps")
                                .email("devops@example.com")
                                .url("https://platzi.com"))
                        .license(new License()
                                .name("Apache 2.0")
                                .url("https://www.apache.org/licenses/LICENSE-2.0")))
                .externalDocs(new ExternalDocumentation()
                        .description("Documentación adicional")
                        .url("https://platzi.com"));
    }
}

