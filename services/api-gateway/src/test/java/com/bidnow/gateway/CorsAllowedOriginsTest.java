/*
 * BidNow Auction System
 */
package com.bidnow.gateway;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.cloud.gateway.config.GlobalCorsProperties;
import org.springframework.web.cors.CorsConfiguration;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * CORS allowed origins default to the local frontend and can be overridden with the
 * comma-separated {@code CORS_ALLOWED_ORIGINS} environment variable (AWS, where the
 * browser origin is the CloudFront hostname).
 */
class CorsAllowedOriginsTest {

    private static final String JWT = "jwt.secret=dGVzdC1zZWNyZXQtdGVzdC1zZWNyZXQtdGVzdC1zZWNyZXQtdGVzdC1zZWNyZXQ=";

    private static CorsConfiguration globalCors(GlobalCorsProperties props) {
        CorsConfiguration config = props.getCorsConfigurations().get("/**");
        assertThat(config).isNotNull();
        return config;
    }

    @Nested
    @SpringBootTest(properties = {JWT, "eureka.client.enabled=false"})
    class Defaults {
        @Autowired
        private GlobalCorsProperties props;

        @Test
        void corsAllowedOriginsDefaultsToLocalhost() {
            CorsConfiguration config = globalCors(props);
            assertThat(config.getAllowedOrigins()).containsExactly("http://localhost:3000");
            assertThat(config.getAllowCredentials()).isTrue();
            assertThat(config.getMaxAge()).isEqualTo(3600L);
            assertThat(config.getAllowedMethods())
                    .containsExactly("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH");
        }
    }

    @Nested
    @SpringBootTest(properties = {JWT, "eureka.client.enabled=false",
            "CORS_ALLOWED_ORIGINS=https://d111.cloudfront.net"})
    class Overridden {
        @Autowired
        private GlobalCorsProperties props;

        @Test
        void corsAllowedOriginsCanBeOverridden() {
            assertThat(globalCors(props).getAllowedOrigins()).containsExactly("https://d111.cloudfront.net");
        }
    }

    @Nested
    @SpringBootTest(properties = {JWT, "eureka.client.enabled=false",
            "CORS_ALLOWED_ORIGINS=https://d111.cloudfront.net,http://localhost:3000"})
    class CommaSeparated {
        @Autowired
        private GlobalCorsProperties props;

        @Test
        void corsAllowedOriginsAcceptsCommaSeparatedList() {
            assertThat(globalCors(props).getAllowedOrigins())
                    .containsExactly("https://d111.cloudfront.net", "http://localhost:3000");
        }
    }
}
