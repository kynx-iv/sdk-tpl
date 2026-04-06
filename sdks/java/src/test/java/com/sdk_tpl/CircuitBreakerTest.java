package com.sdk_tpl;

import com.sdk_tpl.config.SdkTplConfig;
import com.sdk_tpl.errors.ErrorCode;
import com.sdk_tpl.errors.SdkTplException;
import com.sdk_tpl.http.CircuitBreaker;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for the {@link CircuitBreaker} class.
 */
class CircuitBreakerTest {

    private CircuitBreaker circuitBreaker;

    @BeforeEach
    void setUp() {
        // failureThreshold=3, resetTimeout=1000ms for fast tests
        var config = new SdkTplConfig.CircuitBreakerConfig(3, 1000);
        circuitBreaker = new CircuitBreaker(config);
    }

    @Nested
    @DisplayName("Initial State")
    class InitialState {

        @Test
        @DisplayName("should start in CLOSED state")
        void shouldStartClosed() {
            assertEquals(CircuitBreaker.State.CLOSED, circuitBreaker.getState());
        }

        @Test
        @DisplayName("should have zero failure count")
        void shouldHaveZeroFailures() {
            assertEquals(0, circuitBreaker.getFailureCount());
        }

        @Test
        @DisplayName("should allow requests when closed")
        void shouldAllowRequestsWhenClosed() {
            assertDoesNotThrow(() -> circuitBreaker.ensureClosed());
        }
    }

    @Nested
    @DisplayName("State Transitions")
    class StateTransitions {

        @Test
        @DisplayName("should remain CLOSED below failure threshold")
        void shouldRemainClosedBelowThreshold() {
            circuitBreaker.recordFailure();
            circuitBreaker.recordFailure();

            assertEquals(CircuitBreaker.State.CLOSED, circuitBreaker.getState());
            assertEquals(2, circuitBreaker.getFailureCount());
        }

        @Test
        @DisplayName("should transition to OPEN at failure threshold")
        void shouldOpenAtThreshold() {
            circuitBreaker.recordFailure();
            circuitBreaker.recordFailure();
            circuitBreaker.recordFailure();

            assertEquals(CircuitBreaker.State.OPEN, circuitBreaker.getState());
        }

        @Test
        @DisplayName("should reject requests when OPEN")
        void shouldRejectWhenOpen() {
            for (int i = 0; i < 3; i++) {
                circuitBreaker.recordFailure();
            }

            SdkTplException exception = assertThrows(
                    SdkTplException.class,
                    () -> circuitBreaker.ensureClosed()
            );

            assertEquals(ErrorCode.CIRCUIT_OPEN, exception.getCode());
            assertTrue(exception.isRecoverable());
        }

        @Test
        @DisplayName("should transition to HALF_OPEN after reset timeout")
        void shouldTransitionToHalfOpen() throws InterruptedException {
            for (int i = 0; i < 3; i++) {
                circuitBreaker.recordFailure();
            }

            assertEquals(CircuitBreaker.State.OPEN, circuitBreaker.getState());

            // Wait for reset timeout to expire
            Thread.sleep(1100);

            assertEquals(CircuitBreaker.State.HALF_OPEN, circuitBreaker.getState());
        }

        @Test
        @DisplayName("should transition from HALF_OPEN to CLOSED on success")
        void shouldCloseOnSuccessFromHalfOpen() throws InterruptedException {
            for (int i = 0; i < 3; i++) {
                circuitBreaker.recordFailure();
            }

            Thread.sleep(1100);
            assertEquals(CircuitBreaker.State.HALF_OPEN, circuitBreaker.getState());

            circuitBreaker.recordSuccess();

            assertEquals(CircuitBreaker.State.CLOSED, circuitBreaker.getState());
            assertEquals(0, circuitBreaker.getFailureCount());
        }

        @Test
        @DisplayName("should transition from HALF_OPEN to OPEN on failure")
        void shouldReopenOnFailureFromHalfOpen() throws InterruptedException {
            for (int i = 0; i < 3; i++) {
                circuitBreaker.recordFailure();
            }

            Thread.sleep(1100);
            assertEquals(CircuitBreaker.State.HALF_OPEN, circuitBreaker.getState());

            // Failures during HALF_OPEN push back above threshold
            for (int i = 0; i < 3; i++) {
                circuitBreaker.recordFailure();
            }

            assertEquals(CircuitBreaker.State.OPEN, circuitBreaker.getState());
        }
    }

    @Nested
    @DisplayName("Success Recording")
    class SuccessRecording {

        @Test
        @DisplayName("should reset failure count on success")
        void shouldResetFailureCount() {
            circuitBreaker.recordFailure();
            circuitBreaker.recordFailure();
            assertEquals(2, circuitBreaker.getFailureCount());

            circuitBreaker.recordSuccess();

            assertEquals(0, circuitBreaker.getFailureCount());
            assertEquals(CircuitBreaker.State.CLOSED, circuitBreaker.getState());
        }
    }

    @Nested
    @DisplayName("Manual Reset")
    class ManualReset {

        @Test
        @DisplayName("should reset to CLOSED state")
        void shouldResetToClosed() {
            for (int i = 0; i < 3; i++) {
                circuitBreaker.recordFailure();
            }
            assertEquals(CircuitBreaker.State.OPEN, circuitBreaker.getState());

            circuitBreaker.reset();

            assertEquals(CircuitBreaker.State.CLOSED, circuitBreaker.getState());
            assertEquals(0, circuitBreaker.getFailureCount());
            assertDoesNotThrow(() -> circuitBreaker.ensureClosed());
        }
    }
}
