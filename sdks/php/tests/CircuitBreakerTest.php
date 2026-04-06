<?php

declare(strict_types=1);

namespace SdkTpl\Tests;

use PHPUnit\Framework\TestCase;
use SdkTpl\Errors\ErrorCode;
use SdkTpl\Errors\SdkTplException;
use SdkTpl\Http\CircuitBreaker;

class CircuitBreakerTest extends TestCase
{
    public function testStartsInClosedState(): void
    {
        $cb = new CircuitBreaker();
        $this->assertSame(CircuitBreaker::STATE_CLOSED, $cb->getState());
    }

    public function testSuccessfulCallsKeepCircuitClosed(): void
    {
        $cb = new CircuitBreaker(failureThreshold: 3);

        $result = $cb->execute(fn () => 'success');

        $this->assertSame('success', $result);
        $this->assertSame(CircuitBreaker::STATE_CLOSED, $cb->getState());
        $this->assertSame(0, $cb->getFailureCount());
    }

    public function testFailuresBelowThresholdKeepCircuitClosed(): void
    {
        $cb = new CircuitBreaker(failureThreshold: 3);

        for ($i = 0; $i < 2; $i++) {
            try {
                $cb->execute(function (): never {
                    throw SdkTplException::networkError('fail');
                });
            } catch (SdkTplException) {
            }
        }

        $this->assertSame(CircuitBreaker::STATE_CLOSED, $cb->getState());
        $this->assertSame(2, $cb->getFailureCount());
    }

    public function testCircuitOpensAfterReachingFailureThreshold(): void
    {
        $cb = new CircuitBreaker(failureThreshold: 3);

        for ($i = 0; $i < 3; $i++) {
            try {
                $cb->execute(function (): never {
                    throw SdkTplException::networkError('fail');
                });
            } catch (SdkTplException) {
            }
        }

        $this->assertSame(CircuitBreaker::STATE_OPEN, $cb->getState());
    }

    public function testOpenCircuitRejectsRequests(): void
    {
        $cb = new CircuitBreaker(failureThreshold: 1);

        try {
            $cb->execute(function (): never {
                throw SdkTplException::networkError('fail');
            });
        } catch (SdkTplException) {
        }

        try {
            $cb->execute(fn () => 'should not execute');
            $this->fail('Expected SdkTplException to be thrown');
        } catch (SdkTplException $e) {
            $this->assertSame(ErrorCode::CIRCUIT_BREAKER_OPEN, $e->getErrorCode());
        }
    }

    public function testNonRecoverableErrorsDoNotCountAsFailures(): void
    {
        $cb = new CircuitBreaker(failureThreshold: 2);

        for ($i = 0; $i < 5; $i++) {
            try {
                $cb->execute(function (): never {
                    throw SdkTplException::authenticationError();
                });
            } catch (SdkTplException) {
            }
        }

        $this->assertSame(CircuitBreaker::STATE_CLOSED, $cb->getState());
        $this->assertSame(0, $cb->getFailureCount());
    }

    public function testSuccessfulCallAfterFailuresResetsCount(): void
    {
        $cb = new CircuitBreaker(failureThreshold: 5);

        for ($i = 0; $i < 3; $i++) {
            try {
                $cb->execute(function (): never {
                    throw SdkTplException::networkError('fail');
                });
            } catch (SdkTplException) {
            }
        }

        $this->assertSame(3, $cb->getFailureCount());

        $cb->execute(fn () => 'success');

        $this->assertSame(0, $cb->getFailureCount());
        $this->assertSame(CircuitBreaker::STATE_CLOSED, $cb->getState());
    }

    public function testResetRestoresCircuitToInitialState(): void
    {
        $cb = new CircuitBreaker(failureThreshold: 1);

        try {
            $cb->execute(function (): never {
                throw SdkTplException::networkError('fail');
            });
        } catch (SdkTplException) {
        }

        $this->assertSame(CircuitBreaker::STATE_OPEN, $cb->getState());

        $cb->reset();

        $this->assertSame(CircuitBreaker::STATE_CLOSED, $cb->getState());
        $this->assertSame(0, $cb->getFailureCount());
    }
}
