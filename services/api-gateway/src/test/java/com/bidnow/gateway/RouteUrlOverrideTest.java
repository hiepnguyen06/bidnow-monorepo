/*
 * BidNow Auction System
 */
package com.bidnow.gateway;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.cloud.gateway.route.Route;
import org.springframework.cloud.gateway.route.RouteLocator;

import java.net.URI;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Route URIs default to Eureka load-balanced names (local development) and can be
 * overridden per service with {@code <SERVICE>_URL} environment variables (AWS,
 * where Service Connect provides plain DNS names and Eureka is not deployed).
 */
class RouteUrlOverrideTest {

    private static final String JWT = "jwt.secret=dGVzdC1zZWNyZXQtdGVzdC1zZWNyZXQtdGVzdC1zZWNyZXQtdGVzdC1zZWNyZXQ=";

    private static URI uriOf(RouteLocator locator, String routeId) {
        return locator.getRoutes().collectList().block().stream()
                .filter(r -> r.getId().equals(routeId))
                .map(Route::getUri)
                .findFirst()
                .orElseThrow();
    }

    @Nested
    @SpringBootTest(properties = {JWT, "eureka.client.enabled=false"})
    class Defaults {
        @Autowired
        private RouteLocator routeLocator;

        @Test
        void routeUriDefaultsToEureka() {
            assertThat(uriOf(routeLocator, "identity-service")).hasToString("lb://identity-service");
            assertThat(uriOf(routeLocator, "media-websocket")).hasToString("lb://media-service");
        }
    }

    @Nested
    @SpringBootTest(properties = {
            JWT,
            "eureka.client.enabled=false",
            "IDENTITY_SERVICE_URL=http://identity-service:8081",
            "AUCTION_SERVICE_URL=http://auction-service:8083",
            "USER_SERVICE_URL=http://user-service:8082",
            "BIDDING_SERVICE_URL=http://bidding-service:8084",
            "WALLET_SERVICE_URL=http://wallet-service:8085",
            "MEDIA_SERVICE_URL=http://media-service:8086"
    })
    class Overridden {
        @Autowired
        private RouteLocator routeLocator;

        @Test
        void routeUriCanBeOverridden() {
            assertThat(uriOf(routeLocator, "identity-service")).hasToString("http://identity-service:8081");
            assertThat(uriOf(routeLocator, "auction-service")).hasToString("http://auction-service:8083");
            assertThat(uriOf(routeLocator, "user-service")).hasToString("http://user-service:8082");
            assertThat(uriOf(routeLocator, "bidding-service")).hasToString("http://bidding-service:8084");
            assertThat(uriOf(routeLocator, "wallet-service")).hasToString("http://wallet-service:8085");
            assertThat(uriOf(routeLocator, "media-service")).hasToString("http://media-service:8086");
        }

        @Test
        void websocketRouteSharesMediaServiceUrl() {
            assertThat(uriOf(routeLocator, "media-websocket")).hasToString("http://media-service:8086");
        }
    }
}
