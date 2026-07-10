
## Mini APP: IP Monitoring Service

A service for monitoring the availability of IP addresses with a REST API and real-time statistics calculation.

## Description

Backend: Ruby 3.4.2, Roda

Database: PostgreSQL, Sequel ORM

Job queues: Sidekiq, Redis

Validation: dry-validation, dry-types

Containerization: Docker, Docker Compose

## Features
Adding and removing IP addresses

Automatic availability checks every minute

Statistics calculation: average/minimum/maximum RTT, median, standard deviation, packet loss percentage

History of IP address status changes

Background processing via Sidekiq

Full containerization using Docker Compose

## Running

1. Clone the repository
2. Start the containers:
   ```sh
   cd ip_monitoring
   docker-compose up -d
   ```

## Basic Authentication

All API requests require basic authentication.
By default:
Username: admin
Password: admin

## API

### GET /ips
Retrieve a list of all IP addresses.

**Example request:**
```sh
curl -u admin:admin http://localhost:9292/ips
```

**Example response:**
```json
[{"id":3,
  "ip_address":"8.8.8.5",
  "enabled":true,
  "created_at":"2025-12-05T12:44:49+00:00",
  "updated_at":"2025-12-05T12:44:49+00:00"
  }
]
```

### GET /ips/:id/stats
Retrieve statistics for an IP address for a specified period.

**Parameters:**
- `time_from` (optional): datetime in ISO8601 format (e.g., 2025-12-03T10:00:00)
- `time_to` (optional): datetime in ISO8601 format (e.g., 2025-12-05T11:00:00)

If the parameters are not provided, statistics for the last hour are returned.

**Example request:**
```sh
curl -u admin:admin "http://localhost:9292/ips/1/stats?time_from=2025-11-15T10:00:00&time_to=2025-12-05T23:30:00"
```

**Example response:**
```json
{
  "avg_rtt":3.15,
  "min_rtt":3.15,
  "max_rtt":3.15,
  "median_rtt":3.15,
  "std_dev_rtt":null,
  "packet_loss":0.0
}
```

### POST /ips/:id/enable
Enable statistics collection for an IP.

**Example request:**
```sh
curl -u admin:admin -X POST http://localhost:9292/ips/1/enable
```

**Example response:**
```json
{
  "id":1,
  "enabled":true
}
```

### POST /ips/:id/disable
Disable statistics collection for an IP.

**Example request:**
```sh
curl -u admin:admin -X POST http://localhost:9292/ips/1/disable
```

**Example response:**
```json
{
  "id":1,
  "disabled":true
}
```

### POST /ips
Add a new IP address.

**Example request:**
```sh
curl -u admin:admin -X POST -H "Content-Type: application/json" -d '{"ip_address": "8.8.8.1", "enabled": true}' http://localhost:9292/ips
```

**Example response:**
```json
{
  "id":4,
  "ip_address":"8.8.8.1",
  "enabled":true,
  "created_at":"2025-12-05T13:43:29+00:00",
  "updated_at":"2025-12-05T13:43:29+00:00"
}
```
### DELETE /ips/:id
Delete an IP address by ID.

**Example request:**
```sh
curl -u admin:admin -X DELETE http://localhost:9292/ips/1
```


### GET /sidekiq
Access the Sidekiq web interface.

**Example request:**
```sh
curl -u admin:admin http://localhost:9292/sidekiq
```
