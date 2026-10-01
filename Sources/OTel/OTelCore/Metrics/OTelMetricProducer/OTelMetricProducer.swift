//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift OTel open source project
//
// Copyright (c) 2024 the Swift OTel project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// A bridge from third-party metric sources, so they can be plugged into an OpenTelemetry MetricReader as a source of
/// aggregated metric data.
///
/// - Seealso: [OTel specification for Metric Producer](https://github.com/open-telemetry/opentelemetry-specification/blob/v1.29.0/specification/metrics/sdk.md#metricproducer)
protocol OTelMetricProducer: Sendable {
    /// Provides metrics from the MetricProducer to the caller.
    ///
    /// - Returns: a batch of metric points.
    func produce() -> [OTelMetricPoint]
    func produceCancellable() async throws -> [OTelMetricPoint]
}

// Compatibility for existing producers; only cooperative producers qualify for the pilot.
extension OTelMetricProducer {
    func produceCancellable() async throws -> [OTelMetricPoint] {
        try Task.checkCancellation()
        let points = produce()
        try Task.checkCancellation()
        return points
    }
}
