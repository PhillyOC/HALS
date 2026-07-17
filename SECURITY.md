# Security Policy

## Safe deployment

HALS controls local devices and stores API keys, OAuth tokens, device names, IP addresses, and MAC addresses. Keep these files private:

- `Secrets\`
- `Config\AI.json`
- `Config\Connections.json`
- `Knowledge\`
- `Snapshots\`

The web API has no built-in user authentication. Keep its default `localhost` binding. Do not expose it to the internet or an untrusted network.

Use a dedicated, least-privileged account for every integration. Rotate a credential immediately if it is committed, logged, or otherwise disclosed; deleting it from a repository does not revoke it.

## Reporting vulnerabilities

Please report vulnerabilities privately to the repository owner rather than opening a public issue. Do not include live credentials, tokens, personal device data, or network details in a report.
