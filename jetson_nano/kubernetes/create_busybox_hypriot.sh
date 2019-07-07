kubectl run hypriot --image=hypriot/rpi-busybox-httpd --replicas=3 --port=80
kubectl expose deployment hypriot --port 80
sleep 15
kubectl get endpoints hypriot
