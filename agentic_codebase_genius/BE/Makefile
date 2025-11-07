.PHONY: serve ping gen

serve:
\tjac build main.jac
\tjac serve main.jac

ping:
\tcurl -s -X POST http://127.0.0.1:8000/walker/PingV6 \
\t  -H "Authorization: Bearer $${TOKEN}" -H 'Content-Type: application/json' -d '{}' | jq

gen:
\tcurl -s -X POST http://127.0.0.1:8000/walker/GenerateV4 \
\t  -H "Authorization: Bearer $${TOKEN}" -H 'Content-Type: application/json' -d '{}' | jq
