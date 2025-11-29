from flask import Flask, jsonify
import requests
import os
# mcstatus, socket のインポートは削除

app = Flask(__name__)

PROMETHEUS_URL = "http://prometheus:9090"

def query_prometheus(query):
    try:
        response = requests.get(f"{PROMETHEUS_URL}/api/v1/query", params={'query': query})
        data = response.json()
        if data["status"] == "success" and len(data["data"]["result"]) > 0:
            return data["data"]["result"][0]
        return None
    except Exception as e:
        print(f"Error querying Prometheus: {e}")
        return None

@app.route('/')
def hello():
    return jsonify({"message": "Minecraft Monitor API OK", "status": "Running"})

@app.route('/api/status')
def get_status():
    # -------------------------------------------------
    # 1. Prometheusから全メトリクス収集
    # -------------------------------------------------
    # 基本ステータス
    online_res = query_prometheus('minecraft_status_players_online_count')
    max_res = query_prometheus('minecraft_status_players_max_count')
    healthy_res = query_prometheus('minecraft_status_healthy')
    
    # 【復活】Ping (応答時間)
    ping_res = query_prometheus('minecraft_status_response_time_seconds')

    # リソース (cAdvisor)
    cpu_query = 'sum(rate(container_cpu_usage_seconds_total{container_label_io_kubernetes_container_name="minecraft"}[1m])) * 100'
    cpu_res = query_prometheus(cpu_query)

    mem_query = 'sum(container_memory_working_set_bytes{container_label_io_kubernetes_container_name="minecraft"})'
    mem_res = query_prometheus(mem_query)

    limit_query = 'sum(container_spec_memory_limit_bytes{container_label_io_kubernetes_container_name="minecraft"})'
    limit_res = query_prometheus(limit_query)

    # -------------------------------------------------
    # 2. データの整形
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

    # ステータス判定
    if online_res:
        status_text = "Online"
        players_online = int(online_res['value'][1])
        
        # バージョン情報 (Prometheusのラベルから取得)
        if healthy_res and 'metric' in healthy_res:
            version = healthy_res['metric'].get('server_version', 'Unknown')
            
        # 最大人数
        if max_res:
            players_max = int(max_res['value'][1])
            
        # Ping (秒 -> ミリ秒)
        if ping_res:
            val = float(ping_res['value'][1])
            latency = int(val * 1000)

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
            "version": version,
            "latency": latency,
            "cpu_usage": cpu_usage,
            "memory_usage": mem_usage_str,
            "memory_limit": mem_limit_str,
            "memory_percent": mem_percent_str
        }
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)