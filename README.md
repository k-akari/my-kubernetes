# myk8s

## 1. Prometheus UI
ポートフォワードを設定し、localhost:9090へアクセスする。
```bash
$ kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
```

### 使用例
1. コンテナ単位でのCPU使用率の確認
```
rate(node_cpu_seconds_total{mode="user"}[1m])
```

2. Pod単位でのCPU使用時間
```
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod)
```

## 2. AlertManagerの閲覧方法
ポートフォワードを設定し、localhost:9093へアクセスする。
```bash
$ kubectl port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 9093:9093
```

## 3. Grafanaの閲覧方法
1. adminユーザーのパスワードを確認する。
```bash
$ kubectl get secret/kube-prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

2. ポートフォワードを設定し、localhost:30080へアクセスする。
```bash
$ kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 30080:80
```
