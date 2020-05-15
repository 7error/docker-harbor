#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
domains=$(echo $SNI | tr ";" "\n")

str_tmp="";
for addr in $domains
do
    echo "> [$addr]"
    str_tmp=$str_tmp"\""$addr"\",";
done
echo $str_tmp;

cat > ca-config.json <<EOF
{
	"signing": {
		"default": {
			"expiry": "876000h"
		},
		"profiles": {
			"kubernetes": {
				"usages": [
					"signing",
					"key encipherment",
					"server auth",
					"client auth"
				],
				"expiry": "876000h"
			}
		}
	}
}
EOF


cat > ca-csr.json <<EOF
{
  "CN": "root-ca",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "opsnull"
    }
  ],
  "ca": {
    "expiry": "876000h"
 }
}
EOF

cat > harbor-csr.json <<EOF
{
  "CN": "harbor.local",
  "hosts": [
    "127.0.0.1",
    "192.168.1.10",$str_tmp
    "harbor",
    "harbor.default",
    "harbor.default.svc",
    "harbor.local"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "opsnull"
    }
  ]
}
EOF

cat harbor-csr.json;


cfssl gencert -initca ca-csr.json | cfssljson -bare ca
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes harbor-csr.json | cfssljson -bare harbor


openssl genrsa -out private_key.pem 4096
openssl req -new -x509 -key private_key.pem -out root.crt -days 36500 -subj "/"


openssl genrsa -out notary-signer-ca.key 4096
openssl req -new -x509 -key notary-signer-ca.key -out notary-signer-ca.crt -days 36500 -subj "/C=US/ST=California/L=Palo Alto/O=GoHarbor/OU=Harbor/CN=Self-signed by GoHarbor"


cat > notary-signer-csr.json <<EOF
{
  "CN": "notarysigner",
  "hosts": [
    "127.0.0.1",
    "notarysigner",
    "notarysigner.default",
    "notarysigner.default.svc",
    "notarysigner.local"
  ],
  "key": {
    "algo": "rsa",
    "size": 4096
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "opsnull"
    }
  ]
}
EOF

cfssl gencert -ca-key=notary-signer-ca.key -ca=notary-signer-ca.crt -config=ca-config.json -profile=kubernetes notary-signer-csr.json | cfssljson -bare notary-signer

cp ca.pem ca.crt
cp harbor.pem server.crt
cp harbor-key.pem server.key
mv notary-signer.pem notary-signer.crt
mv notary-signer-key.pem notary-signer.key