from flask import Flask, jsonify
import requests
import os
from mcstatus import BedrockServer
import socket

app = Flask(__name__)

# PrometheusのURL
PROMETHEUS_URL = "http://prometheus:9090"

# マイクラサーバーの接続情報 (DevOps VMから見たIP)
MC_SERVER_IP = "192.168.0.20"
MC_SERVER_PORT = 19134

def query_prometheus(query):
    """
    Prometheusからデータを取得するヘルパー関数
    """
    try:
        response = requests.get(f"{PROMETHEUS_URL}/api/v1/query", params={'query': query})
        data = response.json()
        if data["status"] == "success" and len(data["data"]["result"]) > 0:
            return data["data"]["result"][0]
        return None
    except Exception as e:
        print(f"Error querying Prometheus: {e}")
        return None

def get_real_status():
    """
    mcstatusを使ってサーバーに直接問い合わせる関数
    """
    try:
        server = BedrockServer.lookup(f"{MC_SERVER_IP}:{MC_SERVER_PORT}")
        # タイムアウトを0.5秒に設定してレスポンス低下を防ぐ
        status = server.status(timeout=0.5)
        return status
    except Exception as e:
        return None

@app.route('/')
def hello():
    return jsonify({"message": "Minecraft Monitor API OK", "status": "Running"})

@app.route('/api/status')
def get_status():
    # -------------------------------------------------
    # 1. Prometheusからメトリクス収集 (CPU, Mem, Players)
    # -------------------------------------------------
    online_res = query_prometheus('minecraft_status_players_online_count')
    max_res = query_prometheus('minecraft_status_players_max_count')
    
    # K3s用: ラベル名に注意 (container_label_io_kubernetes_container_name)
    cpu_query = 'sum(rate(container_cpu_usage_seconds_total{container_label_io_kubernetes_container_name="minecraft"}[1m])) * 100'
    cpu_res = query_prometheus(cpu_query)

    mem_query = 'sum(container_memory_working_set_bytes{container_label_io_kubernetes_container_name="minecraft"})'
    mem_res = query_prometheus(mem_query)

    limit_query = 'sum(container_spec_memory_limit_bytes{container_label_io_kubernetes_container_name="minecraft"})'
    limit_res = query_prometheus(limit_query)

    # -------------------------------------------------
    # 2. データの整形 & 直接問い合わせ
    # -------------------------------------------------
    # 初期値
    players_online = 0
    players_max = 0
    version = "Unknown"
    latency = 0
    status_text = "Offline"
    
    cpu_usage = "N/A"
    mem_usage_str = "N/A"
    mem_limit_str = "N/A"
    mem_percent_str = ""

    # mcstatusで生データを取得 (バージョン & Ping)
    mc_status = get_real_status()
    
    if mc_status:
        status_text = "Online"
        # 生のバージョン文字列 (例: 1.21.124.01)
        version = mc_status.version.name
        # レイテンシ (秒 -> ミリ秒変換)
        latency = int(mc_status.latency * 1000) 
        
        # プレイヤー数はPrometheusの時系列データを優先するが、なければmcstatusを使う
        if online_res:
            players_online = int(online_res['value'][1])
        else:
            players_online = mc_status.players_online
            
        if max_res:
            players_max = int(max_res['value'][1])
        else:
            players_max = mc_status.players_max
            
    else:
        # mcstatusが失敗しても、Prometheusが生きていればOnlineとみなすフォールバック
        if online_res:
            status_text = "Online"
            players_online = int(online_res['value'][1])
            version = "Detecting..." # サーバーは居るがバージョン応答がない場合

    # CPU整形
    if cpu_res:
        val = float(cpu_res['value'][1])
        cpu_usage = f"{val:.1f}%"
    
    # メモリ整形
    mem_val = 0
    limit_val = 0
    
    if mem_res:
        mem_val = float(mem_res['value'][1])
        mem_usage_str = f"{mem_val / 1048576:.0f} MB"
        
    if limit_res:
        limit_val = float(limit_res['value'][1])
        mem_limit_str = f"{limit_val / 1073741824:.1f} GB"

    if mem_val > 0 and limit_val > 0:
        percent = (mem_val / limit_val) * 100
        mem_percent_str = f"({percent:.1f}%)"

    # -------------------------------------------------
    # 3. レスポンス生成
    # -------------------------------------------------
    return jsonify({
        "status": status_text,
        "players": {
            "online": players_online,
            "max": players_max
        },
        "server": {
            "version": version,      # 詳細バージョン
            "latency": latency,      # Ping (ms)
            "cpu_usage": cpu_usage,
            "memory_usage": mem_usage_str,
            "memory_limit": mem_limit_str,
            "memory_percent": mem_percent_str
        }
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)