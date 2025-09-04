# Security Policy

## Purpose
This project is designed for **lawful recovery and audit** of digital assets owned by the user or by a party who has given explicit, provable authorization.

## Scope & Posture
- **Watch-Only by Default.** The software must not sweep/broadcast transactions by default. Any optional sweep functionality must be explicitly enabled, consented to, and reviewed for legality and risk.
- **Mainnet Priority.** Production focuses on mainnet scanning to reduce confusion and accidental misuse. Testnets are disabled in production builds.
- **No Unauthorized Access.** Any attempt to access, exfiltrate, or manipulate third-party assets or systems without permission is strictly prohibited.

## Reporting Misuse or Security Issues
- If you suspect **abuse**, **misuse**, or **security vulnerabilities**, email: **security@worksdonotchange2.example** (replace with your real address).
- Include: what happened, when, environment, logs (redact secrets), and reproduction steps if applicable.
- For sensitive reports, use our PGP key (optional): **pgp-public-key.asc** (not included by default).

## Handling Sensitive Data
- **Never** commit private keys, seeds, or raw secrets.
- If key material must be stored for recovery: use client-side encryption and server-side envelope encryption; restrict access by strict policy; log access events; and purge after recovery is complete.
- Redact tokens and credentials in logs.

## Responsible Disclosure
We welcome good-faith security research. Do not exploit data, privacy, or availability risks. Do not conduct denial-of-service testing. Coordinate timing so fixes can be deployed safely.

