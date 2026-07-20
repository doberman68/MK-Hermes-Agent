# MK-OS Hermes gateway image — extends Hostinger's pinned base with the Mem0
# pgvector + Gemini deps baked in at BUILD time, so container startup never depends
# on PyPI reachability or a runtime install step. Replaces the old approach of
# reinstalling these deps from mkos-entrypoint.sh on every fresh boot.
#
# Base stays pinned by digest — same anti-drift guarantee as before, one layer up.
# Bump deliberately: see "Bump the image" in vps/README.md.
FROM ghcr.io/hostinger/hvps-hermes-agent@sha256:8bf68cad92c236d6ed0760c1cc268449aad781922277c7d7c994b40ba16a9fd6

# The base image's /opt/hermes/.venv is root-owned with no pip; uv (already present in
# the base) installs into it as root — same mechanism the runtime self-heal used, just
# baked in at build time instead of repeated on every boot. Versions pinned to the set
# already proven working in production (Constitution v1.7/v1.9).
RUN uv pip install --python /opt/hermes/.venv/bin/python \
      "psycopg[binary,pool]==3.3.4" \
      "google-genai==2.12.1" \
    && chown -R hermes:hermes \
      /opt/hermes/.venv/lib/python3.13/site-packages/psycopg* \
      /opt/hermes/.venv/lib/python3.13/site-packages/google_genai* \
      /opt/hermes/.venv/lib/python3.13/site-packages/google/genai \
      /opt/hermes/.venv/lib/python3.13/site-packages/google_auth* \
      /opt/hermes/.venv/lib/python3.13/site-packages/cffi* \
      /opt/hermes/.venv/lib/python3.13/site-packages/cryptography* \
      /opt/hermes/.venv/lib/python3.13/site-packages/pyasn1* \
      /opt/hermes/.venv/lib/python3.13/site-packages/pycparser* \
      /opt/hermes/.venv/lib/python3.13/site-packages/tenacity* \
      /opt/hermes/.venv/lib/python3.13/site-packages/websockets*
