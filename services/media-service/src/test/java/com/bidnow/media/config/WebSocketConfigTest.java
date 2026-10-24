package com.bidnow.media.config;

import org.junit.jupiter.api.Test;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.broker.SimpleBrokerMessageHandler;
import org.springframework.messaging.support.ExecutorSubscribableChannel;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThat;

class WebSocketConfigTest {

    private final WebSocketConfig config = new WebSocketConfig();

    @Test
    void simpleBrokerUsesTenSecondHeartbeats() {
        ExecutorSubscribableChannel channel = new ExecutorSubscribableChannel();
        MessageBrokerRegistry registry = new MessageBrokerRegistry(channel, channel);

        config.configureMessageBroker(registry);

        SimpleBrokerMessageHandler broker = ReflectionTestUtils.invokeMethod(registry, "getSimpleBroker", channel);
        assertThat(broker).isNotNull();
        assertThat((long[]) ReflectionTestUtils.getField(broker, "heartbeatValue"))
                .containsExactly(10_000L, 10_000L);
        assertThat(broker.getTaskScheduler()).isNotNull();
        assertThat(WebSocketConfig.HEARTBEAT_MS).isEqualTo(10_000L);
    }

    @Test
    void schedulerBeanIsDefined() {
        ThreadPoolTaskScheduler scheduler = config.wsHeartbeatScheduler();

        assertThat(scheduler).isNotNull();
        assertThat(scheduler.getThreadNamePrefix()).startsWith("ws-heartbeat");
    }
}
