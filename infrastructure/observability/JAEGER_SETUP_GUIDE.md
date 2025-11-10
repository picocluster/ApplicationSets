# Jaeger Distributed Tracing Setup Guide for PicoCluster

Complete guide for implementing distributed tracing using Jaeger on your PicoCluster.

## Overview

Jaeger is an open-source distributed tracing platform for monitoring and troubleshooting microservices architectures.

### Key Concepts

**Trace**: Complete request path through all services
```
User Request
    ↓
Service A (span 1)
    ↓
Service B (span 2)
    ↓
Database Query (span 3)
    ↓
Response to User
= Complete Trace (3 spans)
```

**Span**: Unit of work within a trace
- Start and end times
- Operation name
- Tags (key-value metadata)
- Logs (timestamped events)
- Parent span reference

**Service**: Application being traced
- Identifies which service generated the span
- Used for service dependency mapping

## Architecture

### Jaeger Components

```
┌──────────────────────────────────────────────┐
│  Applications (Instrumented with OpenTelemetry)
└────────────────────┬─────────────────────────┘
                     │ Emit traces
                     ↓
         ┌──────────────────────┐
         │   Jaeger Agent       │ (DaemonSet on each node)
         │   UDP:6831           │
         └──────────┬───────────┘
                     │ Forward traces
                     ↓
         ┌──────────────────────┐
         │  Jaeger Collector    │ (Process and persist)
         │  HTTP:14268          │
         │  gRPC:14250          │
         └──────────┬───────────┘
                     │ Store
                     ↓
         ┌──────────────────────┐
         │   Storage Backend    │
         │   (BadgerDB/ES)      │
         └──────────┬───────────┘
                     │ Query
                     ↓
         ┌──────────────────────┐
         │    Jaeger UI         │
         │    HTTP:16686        │
         └──────────────────────┘
```

### Data Flow

1. **Application** emits spans (OpenTelemetry instrumentation)
2. **Jaeger Client** batches and sends to Jaeger Agent (UDP)
3. **Jaeger Agent** aggregates and forwards to Collector
4. **Jaeger Collector** processes and stores in backend
5. **Jaeger Query** retrieves from storage
6. **Jaeger UI** visualizes traces and dependencies

## Quick Start

### Step 1: Install Jaeger

```bash
# Deploy Jaeger to cluster
ansible-playbook infrastructure/observability/install_jaeger.ansible
```

Jaeger will:
- Deploy to `observability` namespace
- Start Collector, Agent, and Query services
- Enable BadgerDB storage
- Configure 100% sampling rate

### Step 2: Access Jaeger UI

```bash
# Forward UI port
jaeger-port-forward

# Open browser
http://localhost:16686
```

### Step 3: Instrument Application

Python example:

```python
from jaeger_client import Config

def init_tracer(service_name):
    config = Config(
        config={
            'sampler': {
                'type': 'const',
                'param': 1,  # 100% sampling
            },
            'logging': True,
        },
        service_name=service_name,
        validate=True,
    )
    return config.initialize_tracer()

# In your application
tracer = init_tracer('my-service')

# Use tracer
with tracer.start_active_span('operation-name') as scope:
    scope.span.set_tag('key', 'value')
    # Your code here
    pass
```

### Step 4: View Traces

1. Open Jaeger UI: http://localhost:16686
2. Select service from dropdown
3. View traces and spans
4. Analyze latency and dependencies

## Instrumentation

### OpenTelemetry vs Jaeger Client

**OpenTelemetry** (recommended):
- Vendor-neutral standard
- Works with any backend (Jaeger, DataDog, New Relic, etc.)
- Modern, actively maintained
- Better long-term support

**Jaeger Client** (legacy):
- Jaeger-specific
- Works only with Jaeger backend
- Still supported, but OpenTelemetry preferred

### Python Instrumentation

#### Using OpenTelemetry

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.exporter.jaeger.thrift import JaegerExporter

# Create Jaeger exporter
jaeger_exporter = JaegerExporter(
    agent_host_name="jaeger-agent",
    agent_port=6831,
)

# Set up tracing
trace.set_tracer_provider(TracerProvider())
trace.get_tracer_provider().add_span_processor(
    SimpleSpanProcessor(jaeger_exporter)
)

# Get tracer
tracer = trace.get_tracer(__name__)

# Use in code
with tracer.start_as_current_span("operation-name"):
    # Your code here
    pass
```

#### Using Jaeger Client

```python
from jaeger_client import Config

config = Config(
    config={
        'sampler': {
            'type': 'const',
            'param': 1,
        },
        'local_agent': {
            'reporting_host': 'jaeger-agent',
            'reporting_port': 6831,
        },
    },
    service_name='my-service',
)
tracer = config.initialize_tracer()
```

### Node.js Instrumentation

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { JaegerExporter } = require('@opentelemetry/exporter-jaeger-thrift');

const jaegerExporter = new JaegerExporter({
  host: 'jaeger-agent',
  port: 6831,
});

const sdk = new NodeSDK({
  traceExporter: jaegerExporter,
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();

// Now all requests are automatically traced
```

### Go Instrumentation

```go
import (
    "github.com/uber/jaeger-client-go"
    "github.com/uber/jaeger-client-go/config"
)

func initTracer(serviceName string) (opentracing.Tracer, io.Closer) {
    cfg := &config.Configuration{
        ServiceName: serviceName,
        Sampler: &config.SamplerConfig{
            Type:  "const",
            Param: 1,
        },
        Reporter: &config.ReporterConfig{
            AgentHost: "jaeger-agent",
            AgentPort: 6831,
        },
    }
    tracer, closer, _ := cfg.NewTracer()
    return tracer, closer
}

// Use tracer
span := tracer.StartSpan("operation-name")
defer span.Finish()
```

### Java Instrumentation

```java
import io.jaegertracing.Configuration;
import io.opentelemetry.javaagent.OpenTelemetryAgent;

// Using Jaeger
Configuration config = Configuration
    .fromEnv()
    .withServiceName("my-service");
io.jaegertracing.tracer.Tracer tracer = config.getTracer();

// Or using OpenTelemetry with Jaeger exporter
// Add: -javaagent:opentelemetry-javaagent.jar
// Set: OTEL_EXPORTER_JAEGER_AGENT_HOST=jaeger-agent
```

## Sampling Strategies

### Const Sampler

Always sample (1.0) or never (0.0):

```yaml
sampler:
  type: const
  param: 1  # 1.0 = always, 0.0 = never
```

**Use for**: Development, testing, or low-traffic systems

### Probabilistic Sampler

Sample random X% of traces:

```yaml
sampler:
  type: probabilistic
  param: 0.1  # 10% of traces
```

**Use for**: Production with moderate traffic

### Rate Limiting Sampler

Sample up to N traces per second:

```yaml
sampler:
  type: ratelimiting
  param: 10  # Max 10 traces/second
```

**Use for**: High-traffic systems, predictable overhead

### Remote Sampler

Dynamically adjust from Jaeger server:

```yaml
sampler:
  type: remote
  param: 0.1  # Initial sampling rate
  remote:
    host: jaeger-agent
    port: 5778
```

**Use for**: Production, dynamic adjustment based on load

## Using Jaeger UI

### Finding Traces

1. **Select Service**: Choose from dropdown
2. **Set Time Range**: Last hour, last 24h, custom
3. **Add Tags**: Filter by custom tags
4. **Search**: Click "Find Traces"

### Analyzing Traces

- **Timeline**: Visual request flow
- **Service Name**: Which service processed span
- **Operation**: What operation was performed
- **Duration**: How long each span took
- **Tags**: Custom metadata
- **Logs**: Timestamped events

### Service Dependencies

View service-to-service relationships:

1. Click **Dependencies** tab
2. See all services and connections
3. Click service to drill down
4. Analyze communication patterns

## Integration with Applications

### Web Framework (Flask/Django)

```python
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.django import DjangoInstrumentor

# Flask
FlaskInstrumentor().instrument_app(app)

# Django
DjangoInstrumentor().instrument()
```

### HTTP Requests

```python
from opentelemetry.instrumentation.requests import RequestsInstrumentor

RequestsInstrumentor().instrument()

# Now all requests.get/post automatically traced
```

### Database Queries

```python
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

SQLAlchemyInstrumentor().instrument()

# Now all SQLAlchemy queries automatically traced
```

### Redis

```python
from opentelemetry.instrumentation.redis import RedisInstrumentor

RedisInstrumentor().instrument()

# Now all Redis operations automatically traced
```

## Advanced Tracing

### Custom Spans

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

def process_data(data):
    with tracer.start_as_current_span("process-data") as span:
        span.set_attribute("data.size", len(data))

        with tracer.start_as_current_span("validate"):
            validate(data)

        with tracer.start_as_current_span("transform"):
            result = transform(data)

        span.add_event("processing_complete")
        return result
```

### Adding Tags and Events

```python
with tracer.start_as_current_span("database-query") as span:
    # Set tags (attributes)
    span.set_attribute("db.system", "postgresql")
    span.set_attribute("db.statement", "SELECT * FROM users")
    span.set_attribute("db.rows_affected", 10)

    # Add events (logs)
    span.add_event("query_started")
    result = execute_query()
    span.add_event("query_completed", {"duration_ms": 145})

    return result
```

### Distributed Context Propagation

Traces automatically follow requests between services:

```python
# Service A
with tracer.start_as_current_span("call-service-b"):
    # Context automatically included in headers
    response = requests.get("http://service-b/api")

# Service B (automatic span linking)
@app.route('/api')
def api():
    # Spans automatically linked to Service A trace
    with tracer.start_as_current_span("api-endpoint"):
        return process_request()
```

## Troubleshooting

### Traces Not Appearing

```bash
# 1. Check Jaeger collector is running
kubectl get pods -n observability -l app.kubernetes.io/name=jaeger

# 2. Check agent is accessible
kubectl port-forward -n observability svc/jaeger-agent 6831:6831/udp

# 3. Verify application is sending traces
# Add logging: 'logging': True in Jaeger config

# 4. Check firewall/network policies
kubectl exec <app-pod> -- telnet jaeger-agent 6831

# 5. View collector logs
kubectl logs -n observability -l app.kubernetes.io/name=jaeger -f
```

### High Latency in Traces

```bash
# 1. Check sampling rate (may be low)
# Increase to 1.0 for testing

# 2. Monitor collector resource usage
kubectl top pods -n observability

# 3. Check storage backend
kubectl exec jaeger-pod -- du -sh /var/lib/jaeger/

# 4. Verify network latency
kubectl exec <app-pod> -- ping jaeger-agent
```

### Storage Issues

```bash
# Check storage usage
kubectl exec -n observability <jaeger-pod> -- \
  du -sh /var/lib/jaeger/badger

# Check available disk
kubectl exec -n observability <jaeger-pod> -- df -h

# Prune old data
kubectl exec -n observability <jaeger-pod> -- \
  jaeger-collector --storage.type=badger --badger.ephemeral=false
```

## Performance Optimization

### 1. Optimize Sampling

```yaml
sampler:
  type: probabilistic
  param: 0.01  # 1% for production
```

### 2. Batch Spans

```python
from opentelemetry.sdk.trace.export import BatchSpanProcessor

provider.add_span_processor(
    BatchSpanProcessor(
        jaeger_exporter,
        max_queue_size=2048,
        max_export_batch_size=512,
    )
)
```

### 3. Use Efficient Storage

For production, consider Elasticsearch:

```bash
# Configure Jaeger with Elasticsearch backend
# More scalable than BadgerDB
# Supports retention policies
# Better for high-volume systems
```

### 4. Monitor Jaeger Metrics

Add to Prometheus scrape config:

```yaml
scrape_configs:
  - job_name: 'jaeger'
    static_configs:
      - targets: ['jaeger-collector:14269']
```

## Useful Commands

```bash
# Check status
jaeger-status

# Port-forward UI
jaeger-port-forward

# View client config examples
jaeger-client-config

# Check logs
kubectl logs -n observability -f \
  -l app.kubernetes.io/name=jaeger

# Describe Jaeger services
kubectl describe svc -n observability

# Test agent connectivity
kubectl exec <app-pod> -- \
  echo "" | nc -u jaeger-agent 6831
```

## See Also

- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [OpenTelemetry Instrumentation Libraries](https://opentelemetry.io/docs/instrumentation/)
- [Jaeger Sampling Documentation](https://www.jaegertracing.io/docs/sampling/)

---

**Last Updated**: 2025-11-10
**Status**: Production Ready
