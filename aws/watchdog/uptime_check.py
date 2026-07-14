"""External uptime watchdog for ip_monitoring.

Runs on AWS Lambda (outside our VPC) every 5 minutes via EventBridge. It does
what an in-server monitor structurally cannot: check the app from the *outside*.
A single HTTP GET to the public /up endpoint (not ICMP — Lambda has no raw
sockets) tells us whether the whole stack (kamal-proxy -> Puma -> Rails) answers.

The result is published to CloudWatch as metrics; a CloudWatch alarm watches
them and notifies via SNS. This function itself never talks to SNS.
"""

import os
import time
import urllib.error
import urllib.request

import boto3

TARGET_URL = os.environ["TARGET_URL"]
NAMESPACE = os.environ.get("METRIC_NAMESPACE", "ipmon")
TIMEOUT = float(os.environ.get("TIMEOUT_SECONDS", "5"))
DIMENSIONS = [{"Name": "Target", "Value": "ipmon-app"}]

cloudwatch = boto3.client("cloudwatch")


def _probe():
    """GET TARGET_URL once. Return (is_up: bool, latency_ms: float|None, detail: str)."""
    start = time.monotonic()
    try:
        req = urllib.request.Request(TARGET_URL, method="GET")
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            latency_ms = (time.monotonic() - start) * 1000
            code = resp.getcode()
            return code == 200, latency_ms, f"HTTP {code}"
    except urllib.error.HTTPError as e:
        return False, None, f"HTTP {e.code}"
    except Exception as e:  # timeout, DNS failure, connection refused, ...
        return False, None, f"{type(e).__name__}: {e}"


def handler(event, context):
    is_up, latency_ms, detail = _probe()
    print(f"probe {TARGET_URL} -> up={is_up} latency_ms={latency_ms} ({detail})")

    metrics = [{
        "MetricName": "UptimeUp",
        "Dimensions": DIMENSIONS,
        "Value": 1 if is_up else 0,
        "Unit": "Count",
    }]
    if latency_ms is not None:
        metrics.append({
            "MetricName": "UptimeLatencyMs",
            "Dimensions": DIMENSIONS,
            "Value": latency_ms,
            "Unit": "Milliseconds",
        })
    cloudwatch.put_metric_data(Namespace=NAMESPACE, MetricData=metrics)

    return {"up": is_up, "latency_ms": latency_ms, "detail": detail, "target": TARGET_URL}
