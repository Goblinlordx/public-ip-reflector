# public-ip-reflector

A lightweight, flexible utility to detect your public IP address and inject it into any command or update services like Kubernetes.

## Features

- **Sequential Detection**: Automatically tries multiple IP detection services in sequence with robust fallback logic.
- **Dynamic Injection**: Injects the detected IP into any command using the `{{PUBLIC_IP}}` placeholder.
- **Flexible Modes**: Works as a standalone CLI tool, a command wrapper, or a Kubernetes sidecar/job.
- **Configurable**: Easily customize sources, detection service URLs, and placeholders via environment variables.

## Getting Started

### Prerequisites

- Docker (for containerized usage)
- `curl` (for local script usage)

### Installation

Build the Docker image:

```bash
docker build -t baldiviab/public-ip-reflector .
```

## Deployment

### Helm (Recommended)

#### Option 1: OCI Registry (Direct)
You can install the chart directly from the GitHub Container Registry without cloning the repository:

```bash
helm upgrade --install public-ip-reflector oci://ghcr.io/benbaldivia/charts/public-ip-reflector \
  --set config.reflectTo=k8s \
  --set config.k8sService=my-ddns-svc
```

#### Option 2: Local Chart (from source)
If you have cloned the repository, you can install from the `example` folder:

```bash
helm upgrade --install public-ip-reflector ./charts/public-ip-reflector \
  --set config.reflectTo=k8s \
  --set config.k8sService=my-ddns-svc
```

## Configuration

| Environment Variable | Description | Default |
|----------------------|-------------|---------|
| `IP_SOURCE`          | Space/comma-separated list of sources (e.g., `ifconfig,icanhazip` or custom URL) | `ifconfig icanhazip ident ipecho` |
| `IP_PLACEHOLDER`     | The placeholder string to replace in commands | `{{PUBLIC_IP}}` |
| `REFLECT_TO`         | The target for reflection. Can be `stdout`, `k8s`, or a custom command. | `stdout` |
| `K8S_SERVICE`        | The name of the Kubernetes service to update (when `REFLECT_TO=k8s`) | `ddns-source` |
| `K8S_NAMESPACE`      | The namespace of the service to update (when `REFLECT_TO=k8s`) | `infra` |
| `IP_SERVICE`         | (Legacy) Single URL for IP detection | (none) |

### Default Detection Sequence
By default, the tool attempts to detect your public IP using the following services in order. If one fails (timeout or empty response), it moves to the next:

1.  **ifconfig**: [https://ifconfig.me](https://ifconfig.me)
2.  **icanhazip**: [https://icanhazip.com](https://icanhazip.com)
3.  **ident**: [https://ident.me](https://ident.me)
4.  **ipecho**: [https://ipecho.net/plain](https://ipecho.net/plain)

### Customizing Sources
You can override this sequence or provide custom URLs using the `IP_SOURCE` environment variable (comma or space-separated):

```bash
docker run --rm -e IP_SOURCE="icanhazip,https://api.ipify.org" baldiviab/public-ip-reflector
```

## Usage Examples

### 1. Basic CLI (Prints IP)
```bash
docker run --rm public-ip-reflector
```

### 2. Kubernetes Reflection (Built-in)
Automatically patches a service with the detected IP:
```bash
docker run --rm -e REFLECT_TO=k8s -e K8S_SERVICE=my-svc -v ~/.kube:/root/.kube public-ip-reflector
```

### 3. Custom Reflection Command
```bash
docker run --rm -e REFLECT_TO="curl -X POST -d 'ip={{PUBLIC_IP}}' http://api.com" public-ip-reflector
```

### 4. Command Injection (CLI Arguments)
Pass arguments directly to the container:
```bash
docker run --rm public-ip-reflector echo "My public IP is {{PUBLIC_IP}}"
```

## How it Works

The entrypoint script (`entrypoint.sh`) performs the following steps:
1. Iterates through the list of `IP_SOURCE`.
2. Attempts to fetch the public IP using `curl`, stopping at the first success.
3. If CLI arguments are provided, it executes them as a custom command after placeholder substitution.
4. If no arguments are provided, it uses the `REFLECT_TO` strategy:
    - `stdout`: Prints the IP.
    - `k8s`: Uses `kubectl patch` to update a service's `externalIPs`.
    - `custom`: Executes the `REFLECT_TO` string as a command.

## Dynamic DNS with ExternalDNS

If you are using [ExternalDNS](https://github.com/kubernetes-sigs/external-dns), you can use this tool to dynamically update your DNS records when your public IP changes.

### Strategy: One A-Record + Multiple CNAMEs

1.  **Core Service**: Deploy an empty Kubernetes service named `ddns-source`.
2.  **A-Record**: Annotate this service for ExternalDNS to create an `A` record (e.g., `home.example.com`) pointing to its `externalIPs`.
3.  **Dynamic Update**: Use `public-ip-reflector` to periodically update the `externalIPs` of `ddns-source`.
4.  **Subdomains**: For any other services (e.g., `nextcloud.example.com`, `plex.example.com`), create `CNAME` records pointing to `home.example.com`.

This setup ensures that all your subdomains automatically follow your public IP whenever it changes, while only needing one service to be patched.

## License

MIT
