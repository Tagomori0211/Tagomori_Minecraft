# **Minecraft BE Resource Dashboard ⛏️📊**

## **📖 概要 (Overview)**

Minecraft Bedrock Edition (統合版) サーバーのリソース状況や、ワールド内のアイテムデータを可視化するためのダッシュボードシステムです。  
単なるWebアプリ開発にとどまらず、実際の運用を想定したCI/CDパイプラインの構築や、Dockerコンテナによるマイクロサービス化を実践し、フルスタックな技術習得（SQL, Docker, Python Flask, Nginx, Linux Automation）を目的としています。

### **🎯 開発の目的**

* Minecraftサーバーのワールドデータを定期的に解析し、チェストの中身やリソースの推移を可視化する。  
* **Infrastructure as Code (IaC)** と **DevOps** の実践経験を積む。  
* 自宅サーバー環境（Proxmox）を活用したオンプレミス運用フローの構築。

## **🏗️ システムアーキテクチャ (Architecture)**

本システムは、自宅ラボ環境の Proxmox 上で稼働する仮想マシン群によって構成されています。  
データの取得から反映までを自動化しています。  
graph TD  
    subgraph "MCBE Server VM"  
        MC\[Minecraft BE Server\] \--\>|Backup & SCP Transfer| VM\_Main  
    end

    subgraph "DevOps Main VM (Docker Host)"  
        VM\_Main\[In-Flow Backup Storage\]  
          
        subgraph "Docker Containers"  
            Parser\[🐍 Python Parser\]  
            DB\[(🐘 PostgreSQL)\]  
            API\[⚡ Flask API\]  
            Nginx\[🌐 Nginx Proxy\]  
        end  
          
        VM\_Main \--\>|Trigger| Parser  
        Parser \--\>|Insert Data| DB  
        API \--\>|Query| DB  
        Nginx \--\>|Reverse Proxy| API  
    end

    User((👤 User)) \--\>|Access Dashboard| Nginx

### **🔄 データ処理フロー**

1. **Data Collection**: mcbe\_server\_vm がワールドのバックアップを作成し、dev\_ops\_vm へSCP転送。  
2. **Trigger**: バックアップ着信、またはGitHubへのPushをトリガーに GitHub Actions がパイプラインを実行。  
3. **Ingestion**: python-parser コンテナがバックアップデータを解析し、PostgreSQLへ格納。  
4. **Visualization**: ユーザーはNginx経由でFlaskアプリにアクセスし、ブラウザ上でデータを閲覧。

## **🛠️ 使用技術 (Tech Stack)**

### **Infrastructure & DevOps**

* **OS**: Linux (Ubuntu Server) on Proxmox VE  
* **Container**: Docker, Docker Compose  
* **CI/CD**: GitHub Actions (Self-hosted Runner)  
* **Automation**: SCP triggers, Shell Scripts

### **Backend & Database**

* **Language**: Python 3.x  
* **Framework**: Flask (Gunicorn)  
* **Database**: PostgreSQL 13  
  * アイテムマスタ、チェスト位置、内容物、スナップショット履歴を正規化して管理

### **Frontend & Web Server**

* **Web Server**: Nginx (Reverse Proxy & Static delivery)  
* **Frontend**: HTML5, CSS3, JavaScript

## **💾 データベース設計 (Database Schema)**

ワールドの時系列データを管理するために、以下のテーブル構造を設計しています。

| テーブル名 | 役割 |
| :---- | :---- |
| WorldSnapshots | バックアップ時点のタイムスタンプ管理 |
| Chests | ワールド内のチェスト座標 (X, Y, Z) を管理 |
| Items | MinecraftアイテムのIDと名称（日本語）のマスタ |
| ChestContents | どのチェストに何が何個入っているかの中間テーブル |

## **🚀 今後のロードマップ (Roadmap)**

現在は設計フェーズが完了し、実装フェーズへ移行中です。

* \[x\] **System Design**: アーキテクチャ設計、DBスキーマ定義  
* \[x\] **Infrastructure**: Docker Compose, GitHub Actions設定作成  
* \[ \] **Implementation Phase 1**: PythonによるLevelDB/バックアップ解析ロジックの実装  
* \[ \] **Implementation Phase 2**: Flask APIのエンドポイント作成  
* \[ \] **Implementation Phase 3**: フロントエンドダッシュボードの実装  
* \[ \] **Deploy**: 自宅サーバーへの完全デプロイと稼働テスト

## **💻 開発環境**

* **PC**: Ryzen 9 9950X3D / RAM 64GB  
* **Server**: PRIMERGY TX2540 M1 (Xeon E5-2470 v2 x2 / RAM 192GB) running Proxmox

*Author: @tagomori0211*