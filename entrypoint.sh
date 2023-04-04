#!/usr/bin/env bash
#Alireza <https://github.com/AlirezaAsadian>

WSPATH=${WSPATH:-'argo'}
UUID=${UUID:-'db5b4014-d2da-11ed-afa1-0242ac120002'}

NEZHA_SERVER= 
NEZHA_PORT=
NEZHA_KEY=

ARGO_AUTH=''
ARGO_DOMAIN=

generate_config() {
  cat > config.json << EOF
{
    "log":{
        "access":"/dev/null",
        "error":"/dev/null",
        "loglevel":"none"
    },
    "inbounds":[
        {
            "port":8080,
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "flow":"xtls-rprx-vision"
                    }
                ],
                "decryption":"none",
                "fallbacks":[
                    {
                        "dest":3001
                    },
                    {
                        "path":"/${WSPATH}-vless",
                        "dest":3002
                    },
                    {
                        "path":"/${WSPATH}-vmess",
                        "dest":3003
                    },
                    {
                        "path":"/${WSPATH}-trojan",
                        "dest":3004
                    },
                    {
                        "path":"/${WSPATH}-shadowsocks",
                        "dest":3005
                    }
                ]
            },
            "streamSettings":{
                "network":"tcp"
            }
        },
        {
            "port":3001,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none"
            }
        },
        {
            "port":3002,
            "listen":"127.0.0.1",
            "protocol":"vless",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "level":0
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/${WSPATH}-vless"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3003,
            "listen":"127.0.0.1",
            "protocol":"vmess",
            "settings":{
                "clients":[
                    {
                        "id":"${UUID}",
                        "alterId":0
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/${WSPATH}-vmess"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3004,
            "listen":"127.0.0.1",
            "protocol":"trojan",
            "settings":{
                "clients":[
                    {
                        "password":"${UUID}"
                    }
                ]
            },
            "streamSettings":{
                "network":"ws",
                "security":"none",
                "wsSettings":{
                    "path":"/${WSPATH}-trojan"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        },
        {
            "port":3005,
            "listen":"127.0.0.1",
            "protocol":"shadowsocks",
            "settings":{
                "clients":[
                    {
                        "method":"chacha20-ietf-poly1305",
                        "password":"${UUID}"
                    }
                ],
                "decryption":"none"
            },
            "streamSettings":{
                "network":"ws",
                "wsSettings":{
                    "path":"/${WSPATH}-shadowsocks"
                }
            },
            "sniffing":{
                "enabled":true,
                "destOverride":[
                    "http",
                    "tls",
                    "quic"
                ],
                "metadataOnly":false
            }
        }
    ],
    "dns":{
        "servers":[
            "https+local://8.8.8.8/dns-query"
        ]
    },
    "outbounds":[
        {
            "protocol":"freedom"
        },
        {
            "tag":"WARP",
            "protocol":"wireguard",
            "settings":{
                "secretKey":"cKE7LmCF61IhqqABGhvJ44jWXp8fKymcMAEVAzbDF2k=",
                "address":[
                    "172.16.0.2/32",
                    "fd01:5ca1:ab1e:823e:e094:eb1c:ff87:1fab/128"
                ],
                "peers":[
                    {
                        "publicKey":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                        "endpoint":"162.159.193.10:2408"
                    }
                ]
            }
        }
    ],
    "routing":{
        "domainStrategy":"AsIs",
        "rules":[
            {
                "type":"field",
                "domain":[
                    "domain:openai.com",
                    "domain:ai.com"
                ],
                "outboundTag":"WARP"
            }
        ]
    }
}
EOF
}

generate_argo() {
  cat > argo.sh << ABC
#!/usr/bin/env bash

ARGO_AUTH=${ARGO_AUTH}
ARGO_DOMAIN=${ARGO_DOMAIN}

# 下载并运行 Argo
check_file() {
  [ ! -e cloudflared ] && wget -O cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && chmod +x cloudflared
}

run() {
  if [[ -n "\${ARGO_AUTH}" && -n "\${ARGO_DOMAIN}" ]]; then
    [[ "\$ARGO_AUTH" =~ TunnelSecret ]] && echo "\$ARGO_AUTH" | sed 's@{@{"@g;s@[,:]@"\0"@g;s@}@"}@g' > tunnel.json && echo -e "tunnel: \$(sed "s@.*TunnelID:\(.*\)}@\1@g" <<< "\$ARGO_AUTH")\ncredentials-file: /app/tunnel.json" > tunnel.yml && ./cloudflared tunnel --edge-ip-version auto --config tunnel.yml --url http://localhost:8080 run 2>&1 &
    [[ \$ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]] && ./cloudflared tunnel --edge-ip-version auto run --token ${ARGO_AUTH} 2>&1 &
  else
    ./cloudflared tunnel --edge-ip-version auto --no-autoupdate --logfile argo.log --loglevel info --url http://localhost:8080 2>&1 &
    sleep 5
    ARGO_DOMAIN=\$(cat argo.log | grep -o "info.*https://.*trycloudflare.com" | sed "s@.*https://@@g" | tail -n 1)
  fi
}

export_list() {
  VMESS="{ \"v\": \"2\", \"ps\": \"Argo-Vmess\", \"add\": \"icook.hk\", \"port\": \"443\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\${ARGO_DOMAIN}\", \"path\": \"/${WSPATH}-vmess?ed=2048\", \"tls\": \"tls\", \"sni\": \"\${ARGO_DOMAIN}\", \"alpn\": \"\" }"
  cat > list << EOF
*******************************************
V2-rayN:
----------------------------
vless://${UUID}@icook.hk:443?encryption=none&security=tls&sni=\${ARGO_DOMAIN}&type=ws&host=\${ARGO_DOMAIN}&path=%2F${WSPATH}-vless?ed=2048#Argo-Vless
----------------------------
vmess://\$(echo \$VMESS | base64 -w0)
----------------------------
trojan://${UUID}@icook.hk:443?security=tls&sni=\${ARGO_DOMAIN}&type=ws&host=\${ARGO_DOMAIN}&path=%2F${WSPATH}-trojan?ed=2048#Argo-Trojan
----------------------------
ss://$(echo "chacha20-ietf-poly1305:${UUID}@icook.hk:443" | base64 -w0)@icook.hk:443#Argo-Shadowsocks
*******************************************
EOF
  cat list
}
check_file
run
export_list
ABC
}

generate_nezha() {
  cat > nezha.sh << EOF
#!/usr/bin/env bash

# 哪吒的三个参数
NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=${NEZHA_PORT}
NEZHA_KEY=${NEZHA_KEY}

# 检测是否已运行
check_run() {
  [[ \$(pgrep -laf nezha-agent) ]] && echo "哪吒客户端正在运行中!" && exit
}

# 三个变量不全则不安装哪吒客户端
check_variable() {
  [[ -z "\${NEZHA_SERVER}" || -z "\${NEZHA_PORT}" || -z "\${NEZHA_KEY}" ]] && exit
}

# 下载最新版本 Nezha Agent
download_agent() {
  if [ ! -e nezha-agent ]; then
    URL=\$(wget -qO- -4 "https://api.github.com/repos/naiba/nezha/releases/latest" | grep -o "https.*linux_amd64.zip")
    wget -t 2 -T 10 -N \${URL}
    unzip -qod ./ nezha-agent_linux_amd64.zip && rm -f nezha-agent_linux_amd64.zip
  fi
}

# 运行客户端
run() {
  [[ ! \$PROCESS =~ nezha-agent && -e nezha-agent ]] && ./nezha-agent -s \${NEZHA_SERVER}:\${NEZHA_PORT} -p \${NEZHA_KEY} 2>&1 &
}

check_run
check_variable
download_agent
run
EOF
}

generate_config
generate_argo
generate_nezha
[ -e nezha.sh ] && bash nezha.sh
[ -e argo.sh ] && bash argo.sh
