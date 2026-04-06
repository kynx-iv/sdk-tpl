import XCTest
@testable import SdkTpl

final class CircuitBreakerTests: XCTestCase {

    // MARK: - Default Configuration

    func testStartsInClosedState() async {
        let breaker = CircuitBreaker()
        let state = await breaker.getState()
        XCTAssertEqual(state, .closed)
    }

    func testTransitionsToOpenAfterFailureThreshold() async {
        let breaker = CircuitBreaker(config: CircuitBreakerConfig(
            failureThreshold: 3,
            resetTimeout: 60.0
        ))

        for _ in 0..<3 {
            do {
                let _: Int = try await breaker.execute {
                    throw SdkTplError(code: .networkError, message: "fail")
                }
                XCTFail("Expected error to be thrown")
            } catch {
                // Expected
            }
        }

        let state = await breaker.getState()
        XCTAssertEqual(state, .open)
    }

    func testRejectsCallsWhenOpen() async {
        let breaker = CircuitBreaker(config: CircuitBreakerConfig(
            failureThreshold: 2,
            resetTimeout: 60.0
        ))

        // Trip the breaker
        for _ in 0..<2 {
            do {
                let _: Int = try await breaker.execute {
                    throw SdkTplError(code: .networkError, message: "fail")
                }
            } catch {}
        }

        let state = await breaker.getState()
        XCTAssertEqual(state, .open)

        // Next call should be rejected with circuit-open error
        do {
            let _: Int = try await breaker.execute { return 42 }
            XCTFail("Expected circuit-open error")
        } catch let error as SdkTplError {
            XCTAssertEqual(error.code, .circuitOpen)
        } catch {
            XCTFail("Expected SdkTplError, got \(error)")
        }
    }

    func testResetReturnsToClosed() async {
        let breaker = CircuitBreaker(config: CircuitBreakerConfig(
            failureThreshold: 2,
            resetTimeout: 60.0
        ))

        // Trip the breaker
        for _ in 0..<2 {
            do {
                let _: Int = try await breaker.execute {
                    throw SdkTplError(code: .networkError, message: "fail")
                }
            } catch {}
        }

        let openState = await breaker.getState()
        XCTAssertEqual(openState, .open)

        await breaker.reset()

        let closedState = await breaker.getState()
        XCTAssertEqual(closedState, .closed)
    }

    func testGetStatsReturnsCorrectValues() async {
        let breaker = CircuitBreaker(config: CircuitBreakerConfig(
            failureThreshold: 5,
            resetTimeout: 60.0
        ))

        // Two successes
        for _ in 0..<2 {
            let _: Int = try! await breaker.execute { return 1 }
        }

        // One failure
        do {
            let _: Int = try await breaker.execute {
                throw SdkTplError(code: .networkError, message: "fail")
            }
        } catch {}

        let stats = await breaker.getStats()
        XCTAssertEqual(stats.successes, 2)
        XCTAssertEqual(stats.failures, 1)
        XCTAssertEqual(stats.state, .closed)
    }

    func testSuccessResetFailureCountInClosed() async {
        let breaker = CircuitBreaker(config: CircuitBreakerConfig(
            failureThreshold: 3,
            resetTimeout: 60.0
        ))

        // Two failures (below threshold)
        for _ in 0..<2 {
            do {
                let _: Int = try await breaker.execute {
                    throw SdkTplError(code: .networkError, message: "fail")
                }
            } catch {}
        }

        // One success should reset failure count
        let _: Int = try! await breaker.execute { return 1 }

        // Two more failures -- should not trip (count was reset)
        for _ in 0..<2 {
            do {
                let _: Int = try await breaker.execute {
                    throw SdkTplError(code: .networkError, message: "fail")
                }
            } catch {}
        }

        let state = await breaker.getState()
        XCTAssertEqual(state, .closed, "Should still be closed because success reset the failure counter")
    }
}
