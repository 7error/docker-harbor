{
	"server": {
		"http_addr": ":14443"
	},
	"trust_service": {
		"type": "remote",
		"hostname": "127.0.0.1",
		"port": "7899",
		"tls_ca_file": "./notary-signer-ca.crt",
		"key_algorithm": "ecdsa"
	},
	"logging": {
		"level": "info"
	},
	"storage": {
		"backend": "postgres",
		"db_url": "postgres://postgres:root123@127.0.0.1:5432/notaryserver?sslmode=disable"
    },
    "auth": {
        "type": "token",
        "options": {
            "realm": "EXT_ENDPOINT/service/token",
            "service": "harbor-notary",
            "issuer": "harbor-token-issuer",
            "rootcertbundle": "/etc/registry/root.crt"
        }
    }
}