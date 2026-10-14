# CertScope

Discover subdomains from the certificate data indexed by [crt.name](https://crt.name/).
This small Bash CLI presents the results in a command-line.

## Why crt.name works

When a TLS certificate is issued for a website, it commonly identifies one or
more DNS names that the certificate is valid for. Those names are usually stored
in the certificate's **Subject Alternative Name (SAN)** extension. For example,
a certificate might list `www.example.com` and `api.example.com`.

Certificate Transparency (CT) makes records of publicly trusted certificates
available in public, append-only logs. Search services such as crt.name index
certificate-related DNS names so that they can be queried by domain. crt.name
currently exposes an endpoint that returns names for an apex domain:

```text
https://crt.name/v1/search?apex=example.com
```

The response is newline-separated hostnames. This tool requests that endpoint,
keeps valid names that are subdomains of the requested apex, and removes
duplicates. The approach is useful for passive asset discovery because it can
find names that are not obvious from a website's links or a manually maintained
DNS list.

### What the results mean

Certificate data is an **indicator of names seen in certificates**, not a live
DNS or service check:

- Results may include historical names that no longer resolve or are no longer
  in use.
- A returned hostname is not proof that it is reachable, owned by the same
  organization today, or safe to test.
- Coverage depends on certificates and crt.name's index; results are not
  guaranteed to be complete or real-time.
- Wildcard entries and the apex itself are not emitted by this tool; only
  syntactically valid subdomain hostnames are included.

Use the results only for domains you are authorized to assess.

## Requirements

- Bash 4 or newer
- `curl`

No `jq` or other package is required.

## Install

Clone or download this directory, then make the script executable:

```bash
chmod +x crt-subdomains.sh
```

Run it from this directory with `./crt-subdomains.sh`, or put the script on your
`PATH` to invoke it by name.

## Usage

Search one apex domain:

```bash
./crt-subdomains.sh -d example.com
```

The tool prints one discovered subdomain per line. Status and progress messages
are written to stderr, so stdout can be piped to other tools:

```bash
./crt-subdomains.sh -d example.com -silent | sort -u
```

Save results to a file while also printing them to stdout:

```bash
./crt-subdomains.sh -d example.com -o subdomains.txt
```

For multiple apex domains, create a text file with one domain per line. Blank
lines and lines beginning with `#` are ignored:

```text
example.com
example.org
# customer-owned domains
example.net
```

Then run:

```bash
./crt-subdomains.sh -l domains.txt -o subdomains.txt
```

Results from a list are deduplicated across all domains. Do not use the same
file as both the domain list and output.

## Options

| Option | Description |
| --- | --- |
| `-d`, `-domain <domain>` | Search one apex domain. |
| `-l`, `-list <file>` | Search one apex domain per line from a file. |
| `-o`, `-output <file>` | Write results to a file and stdout. The file is overwritten. |
| `-silent` | Suppress the banner and informational messages; errors are still shown. |
| `-version` | Print the tool version. |
| `-h`, `-help`, `--help` | Show help. |

Only one of `-d` or `-l` may be used per invocation.

## Exit status and errors

- Exit status `0`: all requested searches completed.
- Exit status `1`: a domain was invalid, a list/output file could not be used, or
  an API request failed.
- Exit status `2`: command-line usage error, such as an unknown option or a
  missing required argument.

For a list containing several domains, the tool continues after an invalid
domain or failed request, reports the error, and exits with status `1` after
processing the list.
