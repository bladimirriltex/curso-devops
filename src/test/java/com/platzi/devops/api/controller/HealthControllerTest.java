package com.platzi.devops.api.controller;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(HealthController.class)
@DisplayName("Tests del endpoint /api/v1/health")
class HealthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @DisplayName("GET /api/v1/health → debe retornar 200 OK")
    void health_debeRetornarStatusOk() throws Exception {
        mockMvc.perform(get("/api/v1/health"))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("GET /api/v1/health → debe retornar Content-Type application/json")
    void health_debeRetornarContentTypeJson() throws Exception {
        mockMvc.perform(get("/api/v1/health"))
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON));
    }

    @Test
    @DisplayName("GET /api/v1/health → debe retornar status UP en el cuerpo")
    void health_debeRetornarStatusUp() throws Exception {
        mockMvc.perform(get("/api/v1/health"))
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    @DisplayName("GET /api/v1/health → debe retornar campo message en el cuerpo")
    void health_debeRetornarCampoMessage() throws Exception {
        mockMvc.perform(get("/api/v1/health"))
                .andExpect(jsonPath("$.message").value("API funcionando correctamente"));
    }

    @Test
    @DisplayName("GET /api/v1/health → la respuesta debe contener exactamente los campos status y message")
    void health_debeRetornarCuerpoCompleto() throws Exception {
        mockMvc.perform(get("/api/v1/health"))
                .andExpect(jsonPath("$.status").exists())
                .andExpect(jsonPath("$.message").exists());
    }

}
